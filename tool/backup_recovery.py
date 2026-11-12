"""Custodia portable de claves y copia externa de respaldos ya verificados."""
from __future__ import annotations

import argparse
import base64
import getpass
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile
import uuid

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa


def _label(key_id: str) -> bytes:
    return ('HESM-BACKUP-KEY-v1:' + str(uuid.UUID(key_id))).encode()


def generate_keys(public_path: Path, private_path: Path, password: str):
    if len(password) < 16:
        raise ValueError('Usar una frase de recuperación de al menos 16 caracteres.')
    if public_path.exists() or private_path.exists():
        raise ValueError('Las rutas de custodia deben ser nuevas.')
    private = rsa.generate_private_key(public_exponent=65537, key_size=3072)
    private_path.parent.mkdir(parents=True, exist_ok=True)
    public_path.parent.mkdir(parents=True, exist_ok=True)
    with private_path.open('xb') as file:
        file.write(private.private_bytes(serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8,
            serialization.BestAvailableEncryption(password.encode())))
    with public_path.open('xb') as file:
        file.write(private.public_key().public_bytes(serialization.Encoding.PEM,
            serialization.PublicFormat.SubjectPublicKeyInfo))


def wrap_key(key: bytes, key_id: str, public_pem: bytes) -> dict:
    public = serialization.load_pem_public_key(public_pem)
    if not isinstance(public, rsa.RSAPublicKey) or public.key_size < 3072 or len(key) != 32:
        raise ValueError('Clave de custodia no compatible.')
    ciphertext = public.encrypt(key, padding.OAEP(mgf=padding.MGF1(hashes.SHA256()),
        algorithm=hashes.SHA256(), label=_label(key_id)))
    return {'schema': 1, 'key_id': str(uuid.UUID(key_id)),
            'wrapped_key': base64.b64encode(ciphertext).decode()}


def unwrap_key(packet: dict, private_pem: bytes, password: str) -> bytes:
    if packet.get('schema') != 1:
        raise ValueError('Formato de recuperación no compatible.')
    private = serialization.load_pem_private_key(private_pem, password=password.encode())
    if not isinstance(private, rsa.RSAPrivateKey) or private.key_size < 3072:
        raise ValueError('Clave de custodia no compatible.')
    result = private.decrypt(base64.b64decode(packet['wrapped_key'], validate=True),
        padding.OAEP(mgf=padding.MGF1(hashes.SHA256()), algorithm=hashes.SHA256(),
                     label=_label(packet['key_id'])))
    if len(result) != 32:
        raise ValueError('Clave recuperada inválida.')
    return result


def _copy_verified(source: Path, target: Path):
    with source.open('rb') as file:
        expected = hashlib.file_digest(file, 'sha256').hexdigest()
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=target.parent, suffix='.partial', delete=False) as file:
            temporary = Path(file.name)
            with source.open('rb') as origin:
                shutil.copyfileobj(origin, file)
            file.flush()
            os.fsync(file.fileno())
        with temporary.open('rb') as file:
            actual = hashlib.file_digest(file, 'sha256').hexdigest()
        if actual != expected:
            raise ValueError('La copia externa no coincide con el origen.')
        os.replace(temporary, target)
        return expected
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()


def copy_external(archive: Path, key: bytes, key_id: str, config: dict) -> dict:
    destination = Path(config['destination']).expanduser()
    public_path = Path(config['public_key']).expanduser()
    if not destination.is_absolute() or not public_path.is_absolute():
        raise ValueError('La configuración externa requiere rutas absolutas.')
    packet = wrap_key(key, key_id, public_path.read_bytes())
    output = destination / archive.parent.name
    if output.resolve() == archive.parent.resolve():
        raise ValueError('El destino externo debe ser distinto del respaldo local.')
    output.mkdir(parents=True, exist_ok=False)
    digest = _copy_verified(archive, output / archive.name)
    # La presencia de complete.json indica que se copió y verificó el conjunto.
    (output / 'recovery.json').write_text(json.dumps(packet), encoding='utf-8')
    manifest = {'schema': 1, 'archive': archive.name, 'sha256': digest, 'key_id': key_id}
    (output / 'complete.json').write_text(json.dumps(manifest), encoding='utf-8')
    return {'estado': 'verificado', 'sha256': digest, 'destination': str(output)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='action', required=True)
    generate = commands.add_parser('generate')
    generate.add_argument('--public-key', type=Path, required=True)
    generate.add_argument('--private-key', type=Path, required=True)
    configure = commands.add_parser('configure')
    configure.add_argument('--destination', type=Path, required=True)
    configure.add_argument('--public-key', type=Path, required=True)
    configure.add_argument('--config', type=Path, default=Path(__file__).resolve().parents[1] / '.private/backup-external.json')
    recover = commands.add_parser('recover-key')
    recover.add_argument('--packet', type=Path, required=True)
    recover.add_argument('--private-key', type=Path, required=True)
    recover.add_argument('--key-dir', type=Path, default=Path.home() / '.hesm-backup-keys')
    args = parser.parse_args()
    if args.action == 'generate':
        password = getpass.getpass('Frase de recuperación: ')
        if password != getpass.getpass('Repetir frase: '):
            raise ValueError('Las frases no coinciden.')
        generate_keys(args.public_key, args.private_key, password)
        print('Custodia creada. Guardar la clave privada cifrada fuera de la PC publicadora.')
    elif args.action == 'configure':
        public = args.public_key.resolve()
        wrap_key(os.urandom(32), str(uuid.uuid4()), public.read_bytes())
        args.config.parent.mkdir(parents=True, exist_ok=True)
        args.config.write_text(json.dumps({'destination': str(args.destination.resolve()),
            'public_key': str(public)}, indent=2), encoding='utf-8')
        print('Destino configurado. Se verificará su acceso durante cada copia.')
    else:
        import backup_database as backup
        packet = json.loads(args.packet.read_text(encoding='utf-8'))
        key = unwrap_key(packet, args.private_key.read_bytes(),
                         getpass.getpass('Frase de recuperación: '))
        backup.restricted_dir(args.key_dir)
        target = args.key_dir / (str(uuid.UUID(packet['key_id'])) + '.dpapi')
        with target.open('xb') as file:
            file.write(backup.dpapi(key))
        print('Clave protegida para el usuario actual. Ejecutar ahora la verificación aislada del respaldo.')


if __name__ == '__main__':
    main()

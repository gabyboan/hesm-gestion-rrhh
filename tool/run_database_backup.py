"""Ejecuta el respaldo cifrado y su restauracion de prueba para la tarea Windows."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import msvcrt
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import traceback
import uuid

import backup_database as backup
from backup_recovery import copy_external

REPO = Path(__file__).resolve().parent.parent
CLI_VERSION = '2.122.0'


def write_status(path: Path, value: dict):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    temporary.replace(path)


def native(argv: list[str], *, timeout=180):
    # stdout del dry-run contiene credenciales: nunca imprimirlo ni guardarlo.
    return subprocess.run(argv, cwd=REPO, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          timeout=timeout, creationflags=subprocess.CREATE_NO_WINDOW)


def prepare_docker(docker: str, job: backup.Job):
    def ready():
        try:
            result = native([docker, 'info', '--format', '{{.OSType}}'], timeout=10)
        except subprocess.TimeoutExpired:
            # El pipe puede existir mientras el motor de Docker sigue iniciando.
            return False
        return result.returncode == 0 and result.stdout.strip() == b'linux'

    if not ready():
        backup.emit('iniciando_docker_desktop')
        result = native([docker, 'desktop', 'start', '--detach'], timeout=40)
        job.private_log('docker-inicio', result.stderr)
        if result.returncode:
            raise RuntimeError('No se pudo iniciar Docker Desktop.')
        deadline = time.monotonic() + 180
        while time.monotonic() < deadline:
            if ready():
                break
            time.sleep(2)
        else:
            raise RuntimeError('Docker Linux no estuvo listo a tiempo.')
    result = native([docker, 'image', 'inspect', backup.IMAGE], timeout=30)
    if result.returncode:
        backup.emit('descargando_imagen_postgres')
        result = native([docker, 'pull', backup.IMAGE], timeout=600)
        job.private_log('docker-imagen', result.stderr)
        if result.returncode:
            raise RuntimeError('No se pudo preparar la imagen PostgreSQL fijada.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--backup-root', type=Path,
                        default=REPO / '.private' / 'database-backups' / 'weekly')
    parser.add_argument('--key-dir', type=Path, default=Path.home() / '.hesm-backup-keys')
    parser.add_argument('--external-config', type=Path, default=REPO / '.private' / 'backup-external.json')
    parser.add_argument('--check', action='store_true', help='Comprueba requisitos locales sin crear una copia.')
    args = parser.parse_args()
    root = args.backup_root.resolve()
    job = None
    lock = None
    locked = False
    try:
        if sys.platform != 'win32':
            raise RuntimeError('Esta tarea requiere Windows y DPAPI CurrentUser.')
        linked = (REPO / 'supabase' / '.temp' / 'project-ref').read_text(encoding='utf-8-sig').strip()
        if linked != backup.PROJECT:
            raise RuntimeError('El proyecto vinculado no es HESM-SUPLENCIAS.')
        docker = shutil.which('docker.exe')
        npx = shutil.which('npx.cmd')
        if not docker or not npx:
            raise RuntimeError('Se necesitan Docker Desktop y Node.js con npx en PATH.')
        backup.restricted_dir(root)
        backup.restricted_dir(args.key_dir.resolve())
        if args.check:
            backup.emit('requisitos_locales_verificados', project_ref=backup.PROJECT,
                        backup_root=str(root), python=sys.executable, cli_version=CLI_VERSION)
            return 0
        # Bloqueo de archivo compartido entre sesiones y ejecuciones manuales.
        lock = (root / '.backup.lock').open('a+b')
        if lock.seek(0, os.SEEK_END) == 0:
            lock.write(b'0')
            lock.flush()
        lock.seek(0)
        try:
            msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
        except OSError:
            backup.emit('ejecucion_omitida', motivo='Ya hay otra copia semanal en curso.')
            return 0
        locked = True
        run_id = datetime.now().strftime('%Y-%m-%d_%H%M%S') + '-' + uuid.uuid4().hex[:8]
        job = backup.Job(root / run_id, args.key_dir)
        status = {'project_ref': backup.PROJECT, 'run_id': run_id,
                  'started_at_utc': datetime.now(timezone.utc).isoformat(), 'estado': 'en_curso'}
        write_status(root / 'last-run.json', status)
        prepare_docker(docker, job)
        backup.emit('obteniendo_conexion_temporal', cli_version=CLI_VERSION)
        result = native([npx, '--yes', 'supabase@' + CLI_VERSION, 'db', 'dump', '--linked',
                         '--project-ref', backup.PROJECT, '--dry-run', '--workdir', str(REPO)])
        job.private_log('cli-stderr', result.stderr)
        if result.returncode:
            raise RuntimeError('La CLI no pudo obtener la conexion; comprobar supabase login.')
        archive = backup.source_backup(job, result.stdout)
        del result
        report = backup.restore_test(job, archive)
        # Verificar tambien el contrato persistido que consultara el operador.
        saved = json.loads((job.output / 'verificacion.json').read_text(encoding='utf-8'))
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        if (saved.get('verificada') is not True or saved.get('project_ref') != backup.PROJECT
                or saved.get('sha256') != digest):
            raise RuntimeError('El informe persistido no coincide con la copia.')
        status.update(estado='verificado', finished_at_utc=datetime.now(timezone.utc).isoformat(),
                      archive=str(archive), archive_bytes=archive.stat().st_size, sha256=digest,
                      report=str(job.output / 'verificacion.json'), key_id=job.key_id,
                      tablas_comparadas=report['tablas_comparadas'],
                      filas_comparadas=report['filas_comparadas'],
                      storage_objects=report['storage_objects'], vault_secrets=report['vault_secrets'])
        write_status(root / 'last-success.json', status)
        write_status(root / 'last-run.json', status)
        if args.external_config.exists():
            try:
                configuration = json.loads(args.external_config.read_text(encoding='utf-8'))
                status['external'] = copy_external(archive, job.key, job.key_id, configuration)
                write_status(root / 'last-success.json', status)
                write_status(root / 'last-run.json', status)
            except Exception:
                status.update(estado='verificado_local_fallo_externo')
                job.private_log('external-error', traceback.format_exc().encode())
                write_status(root / 'last-run.json', status)
                backup.emit('fallo_copia_externa', detalle='La copia local sigue verificada; revisar el destino externo.')
                return 1
        backup.emit('backup_semanal_verificado', archivo=str(archive), bytes=archive.stat().st_size,
                    storage_objects=report['storage_objects'], vault_secrets=report['vault_secrets'])
        return 0
    except Exception as error:
        if job is not None:
            job.private_log('tarea-error', traceback.format_exc().encode())
            status.update(estado='fallido', finished_at_utc=datetime.now(timezone.utc).isoformat(),
                          error_type=type(error).__name__, diagnostico='tarea-error.aesgcm')
            write_status(root / 'last-run.json', status)
        backup.emit('backup_semanal_fallido', error_type=type(error).__name__,
                    detalle='Revisar requisitos, login CLI y diagnostico cifrado de la ejecucion.')
        return 1
    finally:
        if lock is not None:
            if locked:
                lock.seek(0)
                msvcrt.locking(lock.fileno(), msvcrt.LK_UNLCK, 1)
            lock.close()


if __name__ == '__main__':
    raise SystemExit(main())

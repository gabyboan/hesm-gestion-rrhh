import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

/// Both version metadata and the installer are authenticated with the same key.
class LanRelease {
  const LanRelease(
      {required this.version,
      required this.fileName,
      required this.length,
      required this.sha256Hex,
      required this.signature});

  final String version;
  final String fileName;
  final int length;
  final String sha256Hex;
  final String signature;
  static const maxInstallerBytes = 150 * 1024 * 1024;

  static List<int> versionParts(String version) {
    if (!RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(version)) {
      throw const FormatException('Versión de actualización inválida.');
    }
    final parts = version.split('.').map(int.parse).toList();
    if (parts.any((part) => part > 65535)) {
      throw const FormatException('Versión fuera de rango.');
    }
    return parts;
  }

  bool isNewerThan(String installed) {
    final current = versionParts(installed);
    final next = versionParts(version);
    for (var i = 0; i < 4; i++) {
      if (next[i] != current[i]) return next[i] > current[i];
    }
    return false;
  }

  static LanRelease fromEnvelope(Uint8List bytes, String publicKey) {
    if (bytes.length > 16384) {
      throw const FormatException('Aviso demasiado grande.');
    }
    final envelope = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final payload = base64Decode(envelope['payload'] as String);
    if (!verifySignature(payload, envelope['signature'] as String, publicKey)) {
      throw const FormatException(
          'La firma del aviso de actualización no es válida.');
    }
    final data = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
    if (data['schema'] != 1) {
      throw const FormatException('Formato no compatible.');
    }
    final version = data['version'] as String;
    versionParts(version);
    final fileName = data['file'] as String;
    if (fileName != 'HESM-Gestion-RRHH-$version-Setup.exe') {
      throw const FormatException('Nombre de instalador no permitido.');
    }
    final length = data['length'] as int;
    final hash = data['sha256'] as String;
    final signature = data['signature'] as String;
    if (length <= 0 ||
        length > maxInstallerBytes ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
        base64Decode(signature).length != 64) {
      throw const FormatException('Datos de instalador inválidos.');
    }
    return LanRelease(
        version: version,
        fileName: fileName,
        length: length,
        sha256Hex: hash,
        signature: signature);
  }

  bool verifyInstaller(Uint8List bytes, String publicKey) =>
      bytes.length == length &&
      sha256.convert(bytes).toString() == sha256Hex &&
      verifySignature(bytes, signature, publicKey);

  static bool verifySignature(
      Uint8List bytes, String signature, String publicKey) {
    try {
      final key = base64Decode(publicKey);
      final sig = base64Decode(signature);
      return key.length == 32 &&
          sig.length == 64 &&
          ed.verify(ed.PublicKey(key), bytes, sig);
    } catch (_) {
      return false;
    }
  }

  static String validateShare(String value) {
    final path =
        value.trim().replaceAll('/', r'\').replaceAll(RegExp(r'\\+$'), '');
    if (!path.startsWith(r'\\') || path.length > 220) {
      throw const FormatException(
          r'Usá una carpeta de red, por ejemplo \\PC-RRHH\Actualizaciones.');
    }
    final parts = path.substring(2).split(r'\');
    if (parts.length < 2 ||
        parts.any((part) =>
            part.isEmpty ||
            part == '.' ||
            part == '..' ||
            RegExp(r'[<>:"|?*\x00-\x1f$]').hasMatch(part) ||
            part.endsWith('.') ||
            part.endsWith(' '))) {
      throw const FormatException('La ruta de red no es válida.');
    }
    return path;
  }
}

bool verifyLanInstaller(Map<String, dynamic> input) =>
    (input['release'] as LanRelease)
        .verifyInstaller(input['bytes'] as Uint8List, input['key'] as String);

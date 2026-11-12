import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show AppExitType;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'lan_release.dart';

class WindowsUpdateService {
  static final instance = WindowsUpdateService();
  static const publicKey = String.fromEnvironment('WINDOWS_UPDATE_PUBLIC_KEY');
  static const version =
      String.fromEnvironment('WINDOWS_APP_VERSION', defaultValue: '1.0.7.8');
  static const _shareKey = 'windows_updates.share.v1';
  static bool get enabled =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.windows &&
      const bool.fromEnvironment('WINDOWS_UPDATES_ENABLED') &&
      publicKey.isNotEmpty;

  String? _share;
  Future<void>? _initialization;
  Future<LanRelease?>? _check;
  bool _installing = false;
  String? get share => _share;
  bool get installing => _installing;

  Future<void> initialize() => _initialization ??= _load();

  Future<void> _load() async {
    try {
      _share = (await SharedPreferences.getInstance()).getString(_shareKey);
      if (_share != null) _share = LanRelease.validateShare(_share!);
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> configure(String path) async {
    final validated = LanRelease.validateShare(path);
    await initialize();
    final saved = await (await SharedPreferences.getInstance())
        .setString(_shareKey, validated);
    if (!saved) {
      throw StateError('No se pudo guardar la carpeta de actualizaciones.');
    }
    _share = validated;
  }

  Future<LanRelease?> checkForUpdates() async {
    await initialize();
    if (_share == null) return null;
    // Keep the underlying request until it ends, even if an SMB timeout occurs.
    // This prevents accumulating requests against an unavailable Windows share.
    final pending =
        _check ??= _readRelease(_share!).whenComplete(() => _check = null);
    return pending.timeout(const Duration(seconds: 12));
  }

  Future<LanRelease?> _readRelease(String root) async {
    final file = File('$root\\latest.json');
    final bytes = await _readLimited(file, 16384);
    final release = LanRelease.fromEnvelope(bytes, publicKey);
    return release.isNewerThan(version) ? release : null;
  }

  Future<void> install(LanRelease release) async {
    if (_installing) return;
    _installing = true;
    Directory? temporary;
    File? local;
    var launched = false;
    try {
      if (_share == null) {
        throw StateError('Falta configurar la carpeta de red.');
      }
      final source =
          File('$_share\\versions\\${release.version}\\${release.fileName}');
      final bytes = await _readLimited(source, release.length)
          .timeout(const Duration(minutes: 3));
      if (!await compute(verifyLanInstaller,
          {'release': release, 'bytes': bytes, 'key': publicKey})) {
        throw const FormatException(
            'El instalador no coincide con su firma. No se instalará.');
      }
      temporary = await Directory.systemTemp.createTemp('hesm-update-');
      local =
          File('${temporary.path}${Platform.pathSeparator}${release.fileName}');
      await local.writeAsBytes(bytes, flush: true);
      // Verify the actual on-disk copy immediately before executing it.
      if (!await compute(verifyLanInstaller, {
        'release': release,
        'bytes': await local.readAsBytes(),
        'key': publicKey
      })) {
        throw const FormatException(
            'La copia local no superó la verificación.');
      }
      await Process.start(
          local.path, ['/SILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-'],
          mode: ProcessStartMode.detached);
      launched = true;
      await ServicesBinding.instance.exitApplication(AppExitType.required);
    } finally {
      _installing = false;
      if (!launched) {
        if (local != null && await local.exists()) await local.delete();
        if (temporary != null && await temporary.exists()) {
          await temporary.delete();
        }
      }
    }
  }

  Future<Uint8List> _readLimited(File file, int limit) async {
    if (await file.length() > limit) {
      throw const FormatException('Archivo de actualización demasiado grande.');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in file.openRead()) {
      if (builder.length + chunk.length > limit) {
        throw const FormatException('Tamaño de actualización no permitido.');
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }
}

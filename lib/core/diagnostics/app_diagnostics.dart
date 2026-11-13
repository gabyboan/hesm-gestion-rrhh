import 'dart:convert';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Diagnóstico mínimo de soporte: nunca serializa el mensaje ni el stack,
/// porque pueden contener credenciales o información del personal.
class AppDiagnostics {
  AppDiagnostics(this.directory, {this.maxBytes = 256 * 1024});
  final Directory directory;
  final int maxBytes;
  Future<void> _queue = Future<void>.value();

  static final instance = AppDiagnostics(Directory(
      '${Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path}'
      '${Platform.pathSeparator}HESM-Gestion-RRHH${Platform.pathSeparator}logs'));

  Future<void> record(String component, Object error) {
    final code = error is PostgrestException
        ? error.code
        : error is AuthException
            ? (error.code ?? error.statusCode)
            : null;
    final event = jsonEncode({
      'time': DateTime.now().toUtc().toIso8601String(),
      'version': const String.fromEnvironment('WINDOWS_APP_VERSION',
          defaultValue: '1.0.8.9'),
      'component': RegExp(r'^[a-z_]{1,40}$').hasMatch(component)
          ? component
          : 'application',
      'type': error.runtimeType.toString(),
      if (code != null && RegExp(r'^[a-zA-Z0-9_-]{1,48}$').hasMatch(code))
        'code': code,
    });
    _queue = _queue.then((_) async {
      await directory.create(recursive: true);
      final file =
          File('${directory.path}${Platform.pathSeparator}events.jsonl');
      if (await file.exists() && await file.length() >= maxBytes) {
        final previous = File('${file.path}.previous');
        if (await previous.exists()) await previous.delete();
        await file.rename(previous.path);
      }
      await file.writeAsString('$event\n', mode: FileMode.append, flush: true);
    }).catchError((Object _) {
      // Una falla de disco al registrar diagnóstico no interrumpe la aplicación.
    });
    return _queue;
  }
}

import 'dart:convert';
import 'dart:io';

class StartupIssue implements Exception {
  const StartupIssue(this.message);
  final String message;
  @override
  String toString() => message;
}

class StartupConfig {
  const StartupConfig(this.endpoint, this.clientKey);
  final Uri endpoint;
  final String clientKey;

  factory StartupConfig.validate(String? url, String? key) {
    final endpoint = Uri.tryParse(url?.trim() ?? '');
    if (endpoint == null ||
        endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment ||
        (endpoint.path.isNotEmpty && endpoint.path != '/')) {
      throw const StartupIssue('Falta una dirección HTTPS válida del sistema. '
          'Contactá al responsable para revisar la configuración.');
    }
    final clientKey = key?.trim() ?? '';
    var valid =
        clientKey.startsWith('sb_publishable_') && clientKey.length > 20;
    if (!valid) {
      try {
        final parts = clientKey.split('.');
        final claims = jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
            as Map;
        valid = parts.length == 3 && claims['role'] == 'anon';
      } catch (_) {
        valid = false;
      }
    }
    if (!valid) {
      throw const StartupIssue('Falta una clave de cliente válida. '
          'Contactá al responsable para revisar la configuración.');
    }
    return StartupConfig(endpoint.replace(path: ''), clientKey);
  }
}

Future<StartupConfig> loadStartupConfig() async {
  const definedUrl = String.fromEnvironment('SUPABASE_URL');
  const definedKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (definedUrl.isNotEmpty && definedKey.isNotEmpty) {
    return StartupConfig.validate(definedUrl, definedKey);
  }
  final candidates = <String>{};
  void addParents(Directory start) {
    var current = start;
    for (var i = 0; i < 8; i++) {
      candidates
          .add('${current.path}${Platform.pathSeparator}credenciales.env');
      final parent = current.parent;
      if (parent.path == current.path) break;
      current = parent;
    }
  }

  candidates.add(
      '${Directory.current.path}${Platform.pathSeparator}credenciales.env');
  candidates.add(
      '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}credenciales.env');
  addParents(Directory.current);
  addParents(File(Platform.resolvedExecutable).parent);
  for (final path in candidates) {
    final file = File(path);
    if (!await file.exists()) continue;
    final env = <String, String>{};
    for (final line in await file.readAsLines()) {
      final text = line.trim();
      if (text.isEmpty || text.startsWith('#')) continue;
      final separator = text.indexOf('=');
      if (separator <= 0) continue;
      final key = text.substring(0, separator).trim();
      var value = text.substring(separator + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      env[key] = value;
    }
    if (env.isEmpty) continue;
    return StartupConfig.validate(
        definedUrl.isNotEmpty ? definedUrl : env['SUPABASE_URL'],
        definedKey.isNotEmpty ? definedKey : env['SUPABASE_ANON_KEY']);
  }
  return StartupConfig.validate(definedUrl, definedKey);
}

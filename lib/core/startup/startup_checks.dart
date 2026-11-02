import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'startup_config.dart';

enum StartupCheck {
  configuration,
  dns,
  internet,
  authentication,
  data,
  application
}

enum CheckStatus { pending, running, passed, failed }

extension StartupCheckLabel on StartupCheck {
  String get label => switch (this) {
        StartupCheck.configuration => 'Configuración de la aplicación',
        StartupCheck.dns => 'Resolución DNS',
        StartupCheck.internet => 'Internet y conexión segura',
        StartupCheck.authentication => 'Servicio de autenticación',
        StartupCheck.data => 'Servicio de datos de Supabase',
        StartupCheck.application => 'Preparación del sistema',
      };
}

class StartupCheckState {
  const StartupCheckState(this.check, this.status, {this.message});
  final StartupCheck check;
  final CheckStatus status;
  final String? message;
}

abstract interface class StartupNetwork {
  Future<void> resolveDns(StartupConfig config);
  Future<void> checkInternet(StartupConfig config);
  Future<void> checkAuthentication(StartupConfig config);
  Future<void> checkData(StartupConfig config);
}

class StartupChecks {
  StartupChecks(
      {required this.loadConfig,
      required this.prepareApplication,
      required this.ensureInstance,
      StartupNetwork? network})
      : network = network ?? IoStartupNetwork();
  final Future<StartupConfig> Function() loadConfig;
  final Future<void> Function(StartupConfig) prepareApplication;
  final Future<void> Function() ensureInstance;
  final StartupNetwork network;

  Future<bool> run(void Function(StartupCheckState) onChange) async {
    StartupConfig? config;
    for (final check in StartupCheck.values) {
      onChange(StartupCheckState(check, CheckStatus.pending));
    }
    for (final check in StartupCheck.values) {
      onChange(StartupCheckState(check, CheckStatus.running));
      try {
        await switch (check) {
          StartupCheck.configuration => () async {
              await ensureInstance();
              config = await loadConfig();
            }(),
          StartupCheck.dns => network.resolveDns(config!),
          StartupCheck.internet => network.checkInternet(config!),
          StartupCheck.authentication => network.checkAuthentication(config!),
          StartupCheck.data => network.checkData(config!),
          StartupCheck.application => prepareApplication(config!),
        };
        onChange(StartupCheckState(check, CheckStatus.passed));
      } catch (error) {
        onChange(StartupCheckState(check, CheckStatus.failed,
            message: _message(check, error)));
        return false;
      }
    }
    return true;
  }

  String _message(StartupCheck check, Object error) {
    if (error is StartupIssue) return error.message;
    if (error is HandshakeException || error is CertificateException) {
      return 'No se pudo validar la conexión segura. Revisá la fecha y hora de Windows '
          'o consultá al responsable de la red.';
    }
    return switch (check) {
      StartupCheck.configuration =>
        'No se pudo leer la configuración o validar la instancia. Reintentá el inicio.',
      StartupCheck.dns =>
        'No se puede encontrar el servidor por su nombre. Revisá la red y el DNS del equipo.',
      StartupCheck.internet =>
        'No se pudo establecer una conexión HTTPS con el servidor. Revisá internet o el acceso de la red del hospital.',
      StartupCheck.authentication =>
        'El servicio de acceso no responde. Esperá unos instantes y reintentá.',
      StartupCheck.data =>
        'El servicio de datos no responde. El sistema permanecerá aquí hasta que se restablezca.',
      StartupCheck.application =>
        'No se pudo preparar el sistema. Reintentá o reiniciá la aplicación.',
    };
  }
}

class IoStartupNetwork implements StartupNetwork {
  @override
  Future<void> resolveDns(StartupConfig config) async {
    final addresses = await InternetAddress.lookup(config.endpoint.host)
        .timeout(const Duration(seconds: 6));
    if (addresses.isEmpty) {
      throw const StartupIssue(
          'El DNS no devolvió una dirección para el servidor. Revisá la red del equipo.');
    }
  }

  @override
  Future<void> checkInternet(StartupConfig config) async {
    await _request(config, '/auth/v1/health',
        method: 'HEAD', includeKey: false);
  }

  @override
  Future<void> checkAuthentication(StartupConfig config) async {
    final body = await _request(config, '/auth/v1/health',
        method: 'GET', requireSuccess: true, readJson: true);
    final data = jsonDecode(body!) as Map;
    if (data['version'] is! String) {
      throw const StartupIssue(
          'El servicio de acceso devolvió una respuesta inesperada. Contactá al responsable del sistema.');
    }
  }

  @override
  Future<void> checkData(StartupConfig config) async {
    // Zero rows: no staff records are retrieved. The OpenAPI root may require
    // a secret key, so it must not be used as the application's health check.
    await _request(config, '/rest/v1/horas_registros',
        method: 'GET',
        query: const {'select': '*', 'limit': '0'},
        dataProbe: true,
        readJson: true);
  }

  Future<String?> _request(StartupConfig config, String path,
      {required String method,
      bool includeKey = true,
      bool requireSuccess = false,
      bool readJson = false,
      bool dataProbe = false,
      Map<String, String>? query}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      return await () async {
        final request = await client.openUrl(method,
            config.endpoint.replace(path: path, queryParameters: query));
        request.followRedirects = false;
        if (includeKey) request.headers.set('apikey', config.clientKey);
        final response = await request.close();
        if (response.isRedirect) {
          throw const StartupIssue(
              'La red está redirigiendo la conexión. Revisá si requiere iniciar sesión en un portal de internet.');
        }
        if (requireSuccess && response.statusCode != 200) {
          if (response.statusCode == 401 || response.statusCode == 403) {
            throw const StartupIssue(
                'El servidor rechazó la configuración de acceso. Contactá al responsable para revisar la clave de cliente.');
          }
          throw StartupIssue(
              'El servicio no está disponible (código ${response.statusCode}). Esperá y reintentá.');
        }
        if (!readJson) return null;
        final bytes = <int>[];
        await for (final chunk in response) {
          if (bytes.length + chunk.length > 16384) {
            throw const FormatException('Response too large');
          }
          bytes.addAll(chunk);
        }
        final body = utf8.decode(bytes);
        if (dataProbe) validateDataProbe(response.statusCode, body);
        return body;
      }()
          .timeout(const Duration(seconds: 10));
    } finally {
      client.close(force: true);
    }
  }

  static void validateDataProbe(int status, String body) {
    final data = jsonDecode(body);
    if (status == 200 && data is List && data.isEmpty) return;
    // An intentional PostgreSQL refusal before login confirms availability,
    // without bypassing permissions or treating any arbitrary 401 as healthy.
    if ((status == 401 || status == 403) &&
        data is Map &&
        (data['code'] == '42501' || data['code'] == 'PT401')) {
      return;
    }
    if (status == 401 || status == 403) {
      throw const StartupIssue(
          'El servidor rechazó la configuración de acceso. Contactá al responsable del sistema.');
    }
    throw StartupIssue(
        'El servicio de datos no está disponible (código $status). Esperá y reintentá.');
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:app_horas/core/startup/backend_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
      'solo permite operar con las capacidades requeridas y detecta migración ausente',
      () async {
    var missing = false;
    var schema = 3;
    var condicion = true;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      await request.drain<void>();
      request.response.headers.contentType = ContentType.json;
      if (missing) {
        request.response.statusCode = 404;
        request.response.write(
            jsonEncode({'code': 'PGRST202', 'message': 'fixture missing'}));
      } else {
        request.response.write(jsonEncode({
          'schema': schema,
          'horas_gremiales': true,
          'horas_idempotencia': true,
          'horas_periodos': true,
          'medicos_condicion': condicion,
        }));
      }
      await request.response.close();
    });
    final client = SupabaseClient(
        'http://127.0.0.1:${server.port}', 'fixture-only',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });
    await requireCompatibleBackend(client);
    condicion = false;
    await expectLater(requireCompatibleBackend(client),
        throwsA(isA<BackendUpdateRequired>()));
    condicion = true;
    schema = 2;
    await expectLater(requireCompatibleBackend(client),
        throwsA(isA<BackendUpdateRequired>()));
    missing = true;
    await expectLater(requireCompatibleBackend(client),
        throwsA(isA<BackendUpdateRequired>()));
  });
}

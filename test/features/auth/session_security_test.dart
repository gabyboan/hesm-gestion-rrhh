import 'dart:convert';
import 'dart:io';

import 'package:app_horas/features/auth/application/session_timeout_service.dart';
import 'package:app_horas/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servidor ficticio en loopback. Nunca usa credenciales ni destinos reales.
class LocalSessionFixture {
  late final HttpServer server;
  late final SupabaseClient client;
  int logoutStatus = 204;
  int logoutCalls = 0;

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    String part(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token = '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({
          'sub': '00000000-0000-4000-8000-000000000001',
          'session_id': '00000000-0000-4000-8000-000000000002',
          'exp': now + 3600,
          'iat': now,
          'aal': 'aal1',
          'amr': <Object>[],
        })}.fixture';
    server.listen((request) async {
      await request.drain<void>();
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/auth/v1/token') {
        request.response.write(jsonEncode({
          'access_token': token,
          'refresh_token': 'fixture-refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': '00000000-0000-4000-8000-000000000001',
            'aud': 'authenticated',
            'role': 'authenticated',
            'created_at': '2026-01-01T00:00:00Z',
            'app_metadata': <String, Object>{},
            'user_metadata': <String, Object>{},
          },
        }));
      } else if (request.uri.path == '/auth/v1/logout') {
        logoutCalls++;
        expect(request.uri.queryParameters['scope'], 'local');
        request.response.statusCode = logoutStatus;
        if (logoutStatus != 204) {
          request.response.write(jsonEncode({'msg': 'Fixture unavailable'}));
        }
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'fixture-publishable',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await client.auth.signInWithPassword(
        email: 'session@example.invalid', password: 'fixture-only-password');
  }

  Future<void> close() async {
    await client.dispose();
    await server.close(force: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Estos tests usan exclusivamente el servidor ficticio 127.0.0.1 de arriba.
  // Retirar el bloqueo HTTP del binding para probar el SDK con respuestas reales.
  HttpOverrides.global = null;
  late LocalSessionFixture fixture;
  late SessionTimeoutService timeout;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fixture = LocalSessionFixture();
    await fixture.start();
    timeout = SessionTimeoutService(fixture.client);
  });
  tearDown(() async {
    timeout.stop();
    await fixture.close();
  });

  test('salir limpia la sesión local y pide revocación al servidor', () async {
    final repository = AuthRepository(fixture.client);
    expect(repository.isLoggedIn, isTrue);
    await repository.signOut();
    expect(repository.session, isNull);
    expect(fixture.logoutCalls, 1);
  });

  test('un error remoto al salir no conserva una sesión local utilizable',
      () async {
    fixture.logoutStatus = 500;
    final repository = AuthRepository(fixture.client);
    await expectLater(repository.signOut(), throwsA(isA<AuthException>()));
    expect(repository.session, isNull);
    expect(fixture.logoutCalls, 1);
  });

  test('reabrir con inactividad vencida cierra la sesión antes de arrancar',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'last_activity_at_ms',
        DateTime.now()
            .subtract(const Duration(minutes: 6))
            .millisecondsSinceEpoch);
    await timeout.start();
    expect(fixture.client.auth.currentSession, isNull);
    expect(fixture.logoutCalls, 1);
    expect(prefs.containsKey('last_activity_at_ms'), isFalse);
  });

  test('una reapertura dentro del límite mantiene la sesión vigente', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'last_activity_at_ms', DateTime.now().millisecondsSinceEpoch);
    await timeout.start();
    expect(fixture.client.auth.currentSession, isNotNull);
    expect(fixture.logoutCalls, 0);
  });
}

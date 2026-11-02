import 'dart:convert';
import 'dart:io';

import 'package:app_horas/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('el SDK conserva el login válido aunque Auth avise contraseña débil',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    String part(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    // JWT local ficticio: únicamente para el servidor HTTP de este test.
    final token = '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({
          'sub': '00000000-0000-4000-8000-000000000001',
          'exp': now + 3600,
          'iat': now,
          'aal': 'aal1',
          'amr': <Object>[],
        })}.fixture';
    server.listen((request) async {
      expect(request.uri.path, '/auth/v1/token');
      final data = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      expect(data['password'], 'corta6');
      request.response.headers.contentType = ContentType.json;
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
          'user_metadata': <String, Object>{}
        },
        'weak_password': {
          'message': 'Password should be at least 12 characters.',
          'reasons': ['length']
        },
      }));
      await request.response.close();
    });
    final client = SupabaseClient(
        'http://127.0.0.1:${server.port}', 'fixture-publishable',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    try {
      final repository = AuthRepository(client);
      await repository.signIn(
          email: 'fixture@example.invalid', password: 'corta6');
      expect(repository.isLoggedIn, isTrue);
      expect(repository.user?.id, '00000000-0000-4000-8000-000000000001');
    } finally {
      await client.dispose();
      await server.close(force: true);
    }
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:app_horas/features/horas/data/horas_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const authorId = '00000000-0000-4000-8000-000000000001';
  late HttpServer server;
  late SupabaseClient client;
  late HorasRepository repository;
  late List<Map<String, dynamic>> rows;
  late List<Uri> profileRequests;
  String? profileError;

  setUp(() async {
    rows = [
      {
        'id': 1,
        'dni': 12345678,
        'carrera_id': 1,
        'fecha': '2026-10-20',
        'periodo': '2026-10-01',
        'tipo': 'OFICIAL',
        'minutos': 60,
        'usuario_carga': authorId,
      },
    ];
    profileRequests = [];
    profileError = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      await request.drain<void>();
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.endsWith('/usuarios')) {
        profileRequests.add(request.uri);
        if (profileError != null) {
          request.response.statusCode =
              profileError == '42501' ? HttpStatus.forbidden : 500;
          request.response.write(jsonEncode({
            'code': profileError,
            'message': 'Respuesta simulada del servidor de prueba',
          }));
        } else {
          request.response.write(jsonEncode([
            {
              'id': '00000000-0000-4000-8000-000000000002',
              'auth_user_id': authorId,
              'nombre': 'Cuenta',
              'apellido': 'Demostración',
            },
          ]));
        }
      } else {
        request.response.write(jsonEncode(rows));
      }
      await request.response.close();
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'placeholder-local-test-key',
    );
    repository = HorasRepository(client);
  });

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test('conserva los registros cuando el acceso a perfiles es denegado',
      () async {
    profileError = '42501';
    final result =
        await repository.registrosPeriodo(periodo: DateTime(2026, 10));
    expect(result.single.minutos, 60);
    expect(result.single.usuarioCarga, authorId);
    expect(profileRequests, hasLength(1));
  });

  test('consulta solamente los UUID de autores de los registros', () async {
    rows.single['usuario_carga'] = "UUID '{00000000000040008000000000000001}'";
    final result = await repository.registrosMes(
      dni: 12345678,
      carreraId: 1,
      periodo: DateTime(2026, 10),
    );
    expect(result.single.usuarioCargaLabel, 'Cuenta Demostración');
    expect(profileRequests.single.queryParameters['or'],
        '(id.in.($authorId),auth_user_id.in.($authorId))');
  });

  test('no consulta perfiles si la RPC ya incluye nombre y apellido', () async {
    rows.single.addAll({
      'usuario_carga_nombre': 'Nombre',
      'usuario_carga_apellido': 'Conservado',
    });
    final result =
        await repository.registrosPeriodo(periodo: DateTime(2026, 10));
    expect(result.single.usuarioCargaLabel, 'Nombre Conservado');
    expect(profileRequests, isEmpty);
  });

  test('un identificador invalido no se interpola en el filtro', () async {
    rows.single['usuario_carga'] = 'texto,auth_user_id.not.is.null';
    final result =
        await repository.registrosPeriodo(periodo: DateTime(2026, 10));
    expect(result, hasLength(1));
    expect(profileRequests, isEmpty);
  });

  test('otros errores del servidor no quedan ocultos como falta de permisos',
      () async {
    profileError = 'XX000';
    await expectLater(
      repository.registrosPeriodo(periodo: DateTime(2026, 10)),
      throwsA(isA<PostgrestException>()),
    );
  });
}

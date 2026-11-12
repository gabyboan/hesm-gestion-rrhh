import 'dart:convert';
import 'dart:io';

import 'package:app_horas/core/cache/session_data_cache.dart';
import 'package:app_horas/features/horas/data/horas_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late HorasRepository repository;
  late Map<String, int> calls;
  setUp(() async {
    calls = {};
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final path = request.uri.path.split('/').last;
      calls.update(path, (n) => n + 1, ifAbsent: () => 1);
      final text = await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      Object result;
      if (path == 'rpc_listado_horas_mes') {
        result = [
          {
            'apellido': 'DEMO',
            'nombre': 'Persona',
            'dni': 1001,
            'carrera_id': 1,
            'carrera': 'Ejemplo'
          }
        ];
      } else if (path == 'rpc_cargar_hora_segura') {
        expect(jsonDecode(text)['p_operacion_id'],
            '00000000-0000-4000-8000-000000000001');
        result = {'id': 1};
      } else if (path == 'rpc_horas_periodos') {
        result = [
          {'periodo': '2026-11-01'},
          {'periodo': '2025-01-01'}
        ];
      } else {
        final offset =
            int.tryParse(request.uri.queryParameters['offset'] ?? '0') ?? 0;
        final limit =
            int.tryParse(request.uri.queryParameters['limit'] ?? '500') ?? 500;
        result = [
          for (var id = offset; id < offset + limit && id < 1101; id++)
            {
              'id': id + 1,
              'dni': 1001,
              'carrera_id': 17,
              'tipo': 'GREMIAL',
              'fecha': '2026-11-12',
              'periodo': '2026-11-01',
              'minutos': 30,
            }
        ];
      }
      request.response.write(jsonEncode(result));
      await request.response.close();
    });
    client = SupabaseClient('http://127.0.0.1:${server.port}', 'fixture-only',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    repository = HorasRepository(client, cache: SessionDataCache());
  });
  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test('reutiliza el padrón y vuelve a consultarlo después de guardar',
      () async {
    await Future.wait([repository.listadoMes(), repository.listadoMes()]);
    await repository.listadoMes();
    expect(calls['rpc_listado_horas_mes'], 1);
    await repository.cargarHora(
        operacionId: '00000000-0000-4000-8000-000000000001',
        dni: 1001,
        carreraId: 1,
        fecha: DateTime(2026, 11, 12),
        tipoDb: 'GREMIAL',
        minutos: 30);
    await repository.listadoMes();
    expect(calls['rpc_listado_horas_mes'], 2);
  });

  test('un informe de más de mil registros incluye todas las páginas',
      () async {
    final rows = await repository.registrosPeriodo(periodo: DateTime(2026, 11));
    expect(rows, hasLength(1101));
    expect(calls['rpc_horas_registros_periodo'], 3);
    await repository.registrosPeriodo(periodo: DateTime(2026, 11));
    expect(calls['rpc_horas_registros_periodo'], 3);
    expect(await repository.periodosConRegistros(),
        {DateTime(2026, 11), DateTime(2025)});
  });
}

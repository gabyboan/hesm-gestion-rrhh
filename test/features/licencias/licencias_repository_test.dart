import 'dart:convert';
import 'dart:io';

import 'package:app_horas/features/licencias/data/licencias_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('catálogo usa los nombres del Excel y conserva códigos y categorías',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    Uri? uri;
    server.listen((request) async {
      uri = request.uri;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode([
        {
          'id': 103,
          'nombre': 'Lic. Profiláctica',
          'codigo': '03',
          'categoria_excel_id': 7,
          'columna_ficha': 'PROFILACTICA',
          'descripcion': 'Licencia Profiláctica (código 03)'
        },
        {
          'id': 10,
          'nombre': 'Lic. por Capacitación',
          'codigo': null,
          'categoria_excel_id': 10
        },
      ]));
      await request.response.close();
    });
    final client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    try {
      final tipos = await LicenciasRepository(client).tipos();
      expect(uri?.path, '/rest/v1/licencias_tipos_excel');
      expect(uri?.queryParameters['order'],
          'categoria_excel_id.asc.nullslast,codigo.asc.nullslast');
      expect(tipos.first.etiqueta, '03 · Lic. Profiláctica');
      expect(tipos.first.categoriaExcelId, 7);
      expect(tipos.first.columnaFicha, 'PROFILACTICA');
      expect(tipos.last.codigo, isNull);
    } finally {
      await client.dispose();
      await server.close(force: true);
    }
  });

  test('Estudio calcula hasta con el calendario del servidor', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    Map<String, dynamic>? datos;
    Uri? uri;
    server.listen((request) async {
      uri = request.uri;
      datos = jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode('2026-01-08'));
      await request.response.close();
    });
    final client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    try {
      expect(
          await LicenciasRepository(client)
              .hastaEstudio(DateTime(2026, 1, 1), 5),
          DateTime(2026, 1, 8));
      expect(uri?.path, '/rest/v1/rpc/rpc_licencias_estudio_hasta');
      expect(datos, {'p_desde': '2026-01-01', 'p_dias': 5});
    } finally {
      await client.dispose();
      await server.close(force: true);
    }
  });

  test(
      'Ficha consulta el historial integrado por persona, con paginación completa',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final solicitudes = <Uri>[];
    final parametros = <Map<String, dynamic>>[];
    server.listen((request) async {
      solicitudes.add(request.uri);
      parametros.add(jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode([
        for (var i = 0; i < (solicitudes.length == 1 ? 500 : 1); i++)
          {
            'id': (solicitudes.length - 1) * 500 + i + 1,
            'dni': 12345678,
            'persona_dni': 12345678,
            'apellido_nombre': 'PERSONA DE PRUEBA',
            'tipo_id': 6,
            'tipo': {'nombre': 'Lic. Anual'},
            'desde': '2026-01-01',
            'hasta': '2026-01-02',
            'dias': 2,
          },
      ]));
      await request.response.close();
    });
    final client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    try {
      final repo = LicenciasRepository(client);
      final rows = await repo.registros(2026, personaDni: 12345678);
      expect(rows.length, 501);
      expect(solicitudes.length, 2);
      for (final uri in solicitudes) {
        expect(uri.path, '/rest/v1/rpc/rpc_licencias_historial');
      }
      for (final datos in parametros) {
        expect(datos['p_persona_dni'], 12345678);
        expect(datos['p_anio'], 2026);
        expect(datos['p_limite'], 500);
      }
      expect(parametros.map((p) => p['p_offset']), [0, 500]);
      await expectLater(repo.registros(2025), throwsArgumentError);
      expect(solicitudes.length, 2);
      await repo.registrosDesde2026(personaDni: 12345678);
      expect(parametros.last['p_anio'], isNull);
      expect(parametros.last['p_persona_dni'], 12345678);
      expect(parametros.last['p_offset'], 0);
    } finally {
      await client.dispose();
      await server.close(force: true);
    }
  });

  test(
      'carga envía código interno, familiar, orden y anotación a la RPC protegida',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    Uri? uri;
    Map<String, dynamic>? datos;
    server.listen((request) async {
      uri = request.uri;
      datos = jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;
      request.response.headers.contentType = ContentType.json;
      request.response.write('69');
      await request.response.close();
    });
    final client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    try {
      await LicenciasRepository(client).guardar(
          dni: 12345678,
          tipoId: 110,
          desde: DateTime(2026, 7, 1),
          hasta: DateTime(2026, 7, 2),
          dniFamiliar: 22222222,
          numeroOrden: 42,
          cantidadFicha: '20/23');
      expect(uri?.path, '/rest/v1/rpc/rpc_licencias_guardar_con_datos');
      expect(datos, containsPair('p_tipo_id', 110));
      expect(datos, containsPair('p_dni_familiar', 22222222));
      expect(datos, containsPair('p_numero_orden', 42));
      expect(datos, containsPair('p_cantidad_ficha', '20/23'));
      expect(datos, containsPair('p_desde', '2026-07-01'));
    } finally {
      await client.dispose();
      await server.close(force: true);
    }
  });
}

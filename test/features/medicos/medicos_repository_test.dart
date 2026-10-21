import 'dart:convert';
import 'dart:io';

import 'package:app_horas/features/medicos/data/medicos_repository.dart';
import 'package:app_horas/features/medicos/domain/parte_medico.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late MedicosRepository repository;
  late List<Map<String, dynamic>> solicitudes;
  String? error;

  setUp(() async {
    solicitudes = [];
    error = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      solicitudes.add(Map<String, dynamic>.from(
          jsonDecode(await utf8.decoder.bind(request).join()) as Map));
      request.response.headers.contentType = ContentType.json;
      if (error != null) {
        request.response.statusCode = HttpStatus.forbidden;
        request.response.write(jsonEncode({
          'code': error,
          'message': 'Sin permiso para emitir partes medicos.',
        }));
      } else if (solicitudes.last['p_familiar_edad_meses'] == null &&
          solicitudes.last.containsKey('p_familiar_edad_meses')) {
        // Reproduce el servidor anterior que rechazaba el parámetro,
        // aunque su valor fuera nulo.
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(jsonEncode({
          'code': 'PGRST202',
          'message': 'Could not find the function in the schema cache',
        }));
      } else {
        request.response.write('123');
      }
      await request.response.close();
    });
    client =
        SupabaseClient('http://127.0.0.1:${server.port}', 'local-test-key');
    repository = MedicosRepository(client);
  });

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test('guarda partes comunes con la firma anterior sin enviar meses nulos',
      () async {
    for (final tipo in [
      TipoParteMedico.domicilio,
      TipoParteMedico.consultorio,
      TipoParteMedico.canje
    ]) {
      expect(
          await repository.crear(dni: 12345678, tipo: tipo, esArt: false), 123);
    }
    expect(solicitudes, hasLength(3));
    expect(solicitudes.every((p) => !p.containsKey('p_familiar_edad_meses')),
        isTrue);
  });

  test('guarda familiares con edad en años sin exigir la función nueva',
      () async {
    final id = await repository.crear(
      dni: 12345678,
      tipo: TipoParteMedico.domicilioFamiliar,
      familiarApellidoNombre: 'Prueba, Familiar',
      familiarEdad: 8,
      familiarParentesco: 'Hijo',
      esArt: false,
    );
    expect(id, 123);
    expect(solicitudes.single['p_familiar_edad'], 8);
    expect(solicitudes.single.containsKey('p_familiar_edad_meses'), isFalse);
  });

  test('conserva la edad en meses, incluido un recién nacido', () async {
    for (final meses in [0, 8, 11]) {
      expect(
          await repository.crear(
            dni: 12345678,
            tipo: TipoParteMedico.domicilioFamiliar,
            familiarApellidoNombre: 'Prueba, Familiar',
            familiarEdad: 0,
            familiarEdadMeses: meses,
            familiarParentesco: 'Hijo',
            esArt: false,
          ),
          123);
    }
    expect(solicitudes.map((p) => p['p_familiar_edad_meses']), [0, 8, 11]);
    expect(solicitudes.every((p) => p['p_familiar_edad'] == 0), isTrue);
  });

  test('propaga los errores de permisos sin repetir el guardado', () async {
    error = '42501';
    await expectLater(
        repository.crear(
          dni: 12345678,
          tipo: TipoParteMedico.consultorio,
          esArt: false,
        ),
        throwsA(
            isA<PostgrestException>().having((e) => e.code, 'code', '42501')));
    expect(solicitudes, hasLength(1));
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:app_horas/features/medicos/data/medicos_repository.dart';
import 'package:app_horas/features/medicos/domain/parte_medico.dart';
import 'package:app_horas/features/medicos/domain/parte_medico_qr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late MedicosRepository repository;
  late List<Map<String, dynamic>> solicitudes;
  String? error;
  Map<String, dynamic>? respuesta;
  List<Map<String, dynamic>>? filas;
  late List<Map<String, dynamic>> carreras;
  late List<String> rutas;

  setUp(() async {
    solicitudes = [];
    error = null;
    respuesta = null;
    filas = null;
    carreras = [];
    rutas = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      rutas.add(request.uri.path);
      solicitudes.add(Map<String, dynamic>.from(
          jsonDecode(await utf8.decoder.bind(request).join()) as Map));
      request.response.headers.contentType = ContentType.json;
      if (error != null) {
        request.response.statusCode = HttpStatus.forbidden;
        request.response.write(jsonEncode({
          'code': error,
          'message': 'Sin permiso para emitir partes medicos.',
        }));
      } else if (request.uri.path.endsWith('/rpc_medicos_carreras')) {
        request.response.write(jsonEncode(carreras));
      } else if (filas != null) {
        request.response.write(jsonEncode(filas));
      } else if (respuesta != null) {
        request.response.write(jsonEncode(respuesta));
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

  test('consulta el día seleccionado en el servidor junto con la búsqueda',
      () async {
    filas = [];
    await repository.registros(fecha: DateTime(2026, 9, 30), buscar: 'Perez');
    expect(rutas.single, endsWith('/rpc_medicos_registros_dia'));
    expect(solicitudes.single, {'p_fecha': '2026-09-30', 'p_buscar': 'Perez'});
  });

  test('clasifica por la carrera de la ficha y consulta cada DNI una sola vez',
      () async {
    filas = [
      for (final entry in [
        (1, 12345678),
        (2, 23456789),
        (3, 34567890),
        (4, 12345678)
      ])
        {
          'id': entry.$1,
          'dni': entry.$2,
          'fecha': '2026-10-23',
          'tipo': 'CONSULTORIO'
        }
    ];
    carreras = [
      {'dni': 12345678, 'carrera_nombre': 'Enfermería', 'es_enfermeria': true},
      {
        'dni': 23456789,
        'carrera_nombre': 'Escalafón General',
        'es_enfermeria': false
      },
    ];
    final partes = await repository.registros(fecha: DateTime(2026, 10, 23));
    expect(partes.map((p) => p.esEnfermeria), [true, false, false, true]);
    expect(partes.first.carreraNombre, 'Enfermería');
    expect(solicitudes.last, {
      'p_dnis': [12345678, 23456789, 34567890]
    });
    expect(rutas.last, endsWith('/rpc_medicos_carreras'));
    expect(partes.first.conDomicilio(null).esEnfermeria, isTrue);
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

  test(
      'consulta el código manual normalizado y conserva el estado de anulación',
      () async {
    respuesta = {
      'parte': {
        'id': 42,
        'dni': 12345678,
        'fecha': '2026-10-23',
        'tipo': 'CONSULTORIO',
        'codigo_qr': '00000422',
        'anulado_at': '2026-10-23T12:00:00Z'
      },
      'controles': [],
    };
    final documento = await repository.documento(codigo: 'pm-0000-0422');
    expect(solicitudes.single, {'p_codigo': '00000422'});
    expect(documento.anulado, isTrue);
    expect(documento.parte.id, 42);
    expect(documento.parte.qr!.codigoManual, 'PM-0000-0422');
  });

  test('el guardado envía la versión y deja autor y hora al servidor',
      () async {
    respuesta = {
      'version': 2,
      'fecha_desde': '2026-10-23',
      'dias_aprobados': 3,
      'fecha_hasta': '2026-10-25',
      'medico_nombre': 'Medico ficticio',
      'medico_matricula': 'DEMO-1',
      'usuario_registro': 'usuario-servidor',
      'registrado_at': '2026-10-23T12:00:00Z',
      'motivo_rectificacion': 'Correccion',
    };
    final control = await repository.guardarControl(
      qr: ParteMedicoQr.parse('00000422'),
      fechaDesde: DateTime(2026, 10, 23),
      diasAprobados: 3,
      medicoNombre: ' Medico ficticio ',
      medicoMatricula: ' DEMO-1 ',
      versionEsperada: 1,
      motivoRectificacion: ' Correccion ',
    );
    expect(solicitudes.single, {
      'p_codigo': '00000422',
      'p_fecha_desde': '2026-10-23',
      'p_dias_aprobados': 3,
      'p_medico_nombre': 'Medico ficticio',
      'p_medico_matricula': 'DEMO-1',
      'p_version_esperada': 1,
      'p_motivo_rectificacion': 'Correccion',
    });
    expect(control.version, 2);
    expect(control.usuarioRegistro, 'usuario-servidor');
    expect(control.fechaHasta, DateTime(2026, 10, 25));
  });
}

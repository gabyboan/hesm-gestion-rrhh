import 'dart:convert';

import 'package:app_horas/features/ficha/data/ficha_licencias_printer.dart';
import 'package:app_horas/features/ficha/domain/ficha_persona.dart';
import 'package:app_horas/features/licencias/domain/licencia.dart';
import 'package:flutter_test/flutter_test.dart';

const persona = FichaPersona(dni: 10000001, nombre: 'PERSONA DEMO', legajo: 1);

LicenciaRegistro registro(int id,
        {int dni = 10000001,
        int anio = 2026,
        String codigo = '01',
        String? columna = 'ANUAL',
        String? observacion,
        String? cantidad,
        bool anulado = false}) =>
    LicenciaRegistro(
        id: id,
        dni: dni,
        nombre: 'PERSONA DEMO',
        tipoId: 101,
        tipo: 'Licencia de prueba',
        codigo: codigo,
        columnaFicha: columna,
        desde: DateTime(anio, 1, 1),
        hasta: DateTime(anio, 1, 2),
        dias: 2,
        dniFamiliar: 10000002,
        numeroOrden: id,
        cantidadFicha: cantidad,
        observacion: observacion,
        anulado: anulado);

void main() {
  test(
      'documentación pendiente conserva gris en las continuaciones sin orden ni código inventado',
      () async {
    final pendiente = LicenciaRegistro.fromJson({
      'id': 500,
      'dni': persona.dni,
      'apellido_nombre': persona.nombre,
      'tipo_id': 16,
      'tipo': {'nombre': 'Lic. Gremial', 'codigo': null},
      'desde': '2026-04-09',
      'hasta': '2026-04-09',
      'dias': 1,
      'documentacion_pendiente': true,
      'observacion':
          'Certificado pendiente. ${List.filled(30, 'Referencia').join(' ')}',
    });
    final filas = FichaLicenciasPrinter.paginar(
            persona: persona, registros: [pendiente, registro(501)], anio: 2026)
        .expand((p) => p)
        .toList();
    final grises = filas.where((f) => f.registroId == 500).toList();
    expect(grises.length, greaterThan(1));
    expect(
        grises.every((f) => f.documentacionPendiente && f.columnas[17].isEmpty),
        isTrue);
    expect(grises.first.columnas[0], isEmpty);
    expect(grises.first.columnas.sublist(10, 16),
        ['9', '4', '2026', '/', '/', '/']);
    expect(grises.map((f) => f.columnas[16].replaceAll('\n', '')).join(),
        contains('Documentación pendiente'));
    expect(
        filas
            .where((f) => f.registroId == 501)
            .every((f) => !f.documentacionPendiente),
        isTrue);
    final pdf = await FichaLicenciasPrinter.generar(
        persona: persona, registros: [pendiente], anio: 2026);
    expect(latin1.decode(pdf), startsWith('%PDF-'));
  });
  test('imprevistos del módulo imprimen código, Art. 8 y número de orden', () {
    final registros = [
      for (var i = 1; i <= 3; i++)
        LicenciaRegistro.fromJson({
          'id': -i,
          'imprevisto_id': i,
          'dni': persona.dni,
          'apellido_nombre': persona.nombre,
          'tipo_id': i == 1 ? 143 : 198,
          'tipo': {
            'nombre': 'Imprevisto',
            'codigo': i == 1 ? '43' : '98',
            'columna_ficha': 'ART8'
          },
          'desde': '2026-0$i-01',
          'hasta': '2026-0$i-01',
          'dias': 1,
          'numero_orden': 100 + i,
        }),
    ];
    final filas = FichaLicenciasPrinter.paginar(
            persona: persona, registros: registros, anio: 2026)
        .single;
    expect(filas.map((f) => f.columnas[0]), ['43', '98', '98']);
    expect(filas.map((f) => f.columnas[7]), ['1', '1', '1']);
    expect(filas.map((f) => f.columnas[17]), ['101', '102', '103']);
    expect(filas.every((f) => f.columnas.sublist(13, 16).join(' ') == '/ / /'),
        isTrue);
    expect(filas.map((f) => f.registroId).toSet().length, 3);
  });

  test('Hasta distingue una fecha única de un día hábil que abarca varios días',
      () {
    LicenciaRegistro estudio(int id, DateTime desde, DateTime hasta) =>
        LicenciaRegistro(
            id: id,
            dni: persona.dni,
            nombre: persona.nombre,
            tipoId: 129,
            tipo: 'Lic. por Estudio',
            codigo: '29',
            columnaFicha: 'ESTUDIO',
            desde: desde,
            hasta: hasta,
            dias: 1);
    final unica = estudio(1, DateTime(2026, 7, 6, 8), DateTime(2026, 7, 6, 17));
    final finDeSemana = estudio(2, DateTime(2026, 7, 4), DateTime(2026, 7, 6));
    final filas = FichaLicenciasPrinter.paginar(
            persona: persona, registros: [unica, finDeSemana], anio: 2026)
        .single;
    expect(filas.singleWhere((f) => f.registroId == 1).columnas.sublist(10, 16),
        ['6', '7', '2026', '/', '/', '/']);
    expect(filas.singleWhere((f) => f.registroId == 2).columnas.sublist(13, 16),
        ['6', '7', '2026']);
    expect(unica.hasta, DateTime(2026, 7, 6, 17));
    expect(finDeSemana.dias, 1);
  });

  test('la ficha continúa tantas hojas como necesite sin perder cargas', () {
    for (final caso in {
      0: [0],
      19: [19],
      20: [19, 1],
      40: [19, 21],
      41: [19, 21, 1],
      85: [19, 21, 21, 21, 3]
    }.entries) {
      final paginas = FichaLicenciasPrinter.paginar(
          persona: persona,
          registros: [for (var i = caso.key; i > 0; i--) registro(i)],
          anio: 2026);
      expect(paginas.map((p) => p.length), caso.value);
      expect(paginas.expand((p) => p).map((r) => r.registroId),
          [for (var i = 1; i <= caso.key; i++) i]);
    }
  });

  test('ubicación de códigos, cantidad literal, familiar y orden', () {
    final r = FichaLicenciasPrinter.paginar(
            persona: persona,
            registros: [
              registro(42,
                  codigo: '03', columna: 'PROFILACTICA', cantidad: '20/23')
            ],
            anio: 2026)
        .single
        .single;
    expect(r.columnas[0], '03');
    expect(r.columnas[1], isEmpty);
    expect(r.columnas[3], '20/23');
    expect(r.columnas[10], '1');
    expect(r.columnas[15], '2026');
    expect(r.columnas[16].replaceAll('\n', ''), contains('DNI: 10000002'));
    expect(r.columnas[17], '42');
    final art8 = FichaLicenciasPrinter.paginar(
            persona: persona,
            registros: [registro(1, codigo: '98', columna: 'ART8')],
            anio: 2026)
        .single
        .single;
    expect(art8.columnas[7], '2');
  });

  test('observaciones extensas continúan incluso entre hojas sin repetir días',
      () {
    final texto = List.filled(200, 'áéíóú').join();
    final paginas = FichaLicenciasPrinter.paginar(
        persona: persona,
        registros: [registro(1, observacion: texto)],
        anio: 2026);
    expect(paginas.length, 2);
    final filas = paginas.expand((p) => p).toList();
    expect(filas.first.continuacion, isFalse);
    expect(
        filas.skip(1).every((r) =>
            r.continuacion && r.columnas[1].isEmpty && r.columnas[10].isEmpty),
        isTrue);
    expect(filas.map((r) => r.columnas[16].replaceAll('\n', '')).join(),
        'DNI: 10000002 / $texto');
  });

  test('acumulada continúa años, excluye anuladas y anteriores a 2026', () {
    final registros = [
      registro(1, anio: 2025),
      registro(2),
      registro(3, anio: 2027),
      registro(4, anulado: true)
    ];
    expect(
        FichaLicenciasPrinter.paginar(
                persona: persona, registros: registros, anio: null)
            .expand((p) => p)
            .map((r) => r.registroId),
        [2, 3]);
    expect(
        FichaLicenciasPrinter.paginar(
                persona: persona, registros: registros, anio: 2027)
            .expand((p) => p)
            .map((r) => r.registroId),
        [3]);
    expect(
        () => FichaLicenciasPrinter.paginar(
            persona: persona, registros: [], anio: 2025),
        throwsArgumentError);
    expect(
        () => FichaLicenciasPrinter.paginar(
            persona: persona,
            registros: [registro(5, dni: 20000001)],
            anio: null),
        throwsArgumentError);
  });

  test('códigos sin columna específica conservan su descripción y cantidad',
      () {
    final paginas = FichaLicenciasPrinter.paginar(
        persona: persona,
        registros: [registro(1, codigo: '26', columna: null)],
        anio: 2026);
    final texto = paginas
        .expand((p) => p)
        .map((r) => r.columnas[16].replaceAll('\n', ''))
        .join();
    expect(texto, contains('Licencia de prueba: 2 días'));
  });

  test('el PDF contiene tres páginas A4 y repite identidad en continuaciones',
      () async {
    final bytes = await FichaLicenciasPrinter.generar(
        persona: persona,
        registros: [for (var i = 1; i <= 41; i++) registro(i)],
        anio: null);
    final pdf = latin1.decode(bytes);
    expect(pdf, startsWith('%PDF-'));
    expect(RegExp(r'/Type\s*/Page\b').allMatches(pdf).length, 3);
    expect('(PERSONA)'.allMatches(pdf).length, 3);
    expect('(DEMO)'.allMatches(pdf).length, 3);
  });
}

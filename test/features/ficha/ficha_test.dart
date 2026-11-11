import 'package:app_horas/features/ficha/application/ficha_providers.dart';
import 'package:app_horas/features/ficha/domain/ficha_resumen.dart';
import 'package:app_horas/features/ficha/domain/ficha_persona.dart';
import 'package:app_horas/features/ficha/presentation/ficha_page.dart';
import 'package:app_horas/features/licencias/domain/licencia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';

import 'ficha_printing_fake.dart';

LicenciaRegistro registro(
    {int id = 1,
    int dni = 12345678,
    String nombre = 'PERSONA UNO',
    bool anulado = false,
    DateTime? desde,
    DateTime? hasta}) {
  final inicio = desde ?? DateTime(2026, 12, 30);
  final fin = hasta ?? DateTime(2027, 1, 2);
  return LicenciaRegistro(
      id: id,
      dni: dni,
      nombre: nombre,
      tipoId: 6,
      tipo: 'Lic. Anual',
      desde: inicio,
      hasta: fin,
      dias: diasLicencia(inicio, fin),
      anulado: anulado);
}

void main() {
  test('dos francos en una fecha conservan cantidad y calendario separados', () {
    final franco = LicenciaRegistro.fromJson({
      'id': 10,
      'dni': 12345678,
      'apellido_nombre': 'PRUEBA',
      'tipo_id': 160,
      'tipo': {'nombre': 'Franco', 'codigo': '60', 'columna_ficha': 'FRANCO'},
      'desde': '2026-03-23',
      'hasta': '2026-03-23',
      'dias': 2,
      'dias_calendario': 1,
      'cantidad_ficha': '2',
      'cantidad_dias_ficha': 2,
      'dias_por_anio': {'2026': 2},
    });
    expect(resumirLicencias([franco], 2026).single.dias, 2);
    expect(franco.dias, 2);
    expect(franco.diasCalendario, 1);
    expect(franco.desde, franco.hasta);
    expect(franco.cantidadFicha, '2');
  });
  test('papel conserva días anotados, año del cupo y origen PDF en el resumen',
      () {
    final licencia = LicenciaRegistro.fromJson({
      'id': 9,
      'dni': 12345678,
      'apellido_nombre': 'PRUEBA',
      'tipo_id': 101,
      'tipo': {'nombre': 'Lic. Anual', 'codigo': '01'},
      'desde': '2026-01-01',
      'hasta': '2026-01-19',
      'dias': 15,
      'dias_calendario': 19,
      'cantidad_ficha': '15/25',
      'cantidad_dias_ficha': 15,
      'anio_cupo': 2025,
      'dias_por_anio': {'2026': 15},
      'origen_documento': 'PDF',
      'origen_pagina': 3,
      'origen_fila': 304,
    });
    expect(resumirLicencias([licencia], 2026).single.dias, 15);
    expect(resumirLicencias([licencia], 2025), isEmpty);
    expect(licencia.diasCalendario, 19);
    expect(licencia.anioCupo, 2025);
    expect(licencia.referenciaOrigen, 'PDF: página 3, renglón 4');
    expect(licencia.unidadDias, 'días según ficha');
  });
  test('Estudio reparte hábiles entre años y conserva los días calendario', () {
    final estudio = LicenciaRegistro.fromJson({
      'id': 1,
      'dni': 12345678,
      'apellido_nombre': 'PERSONA UNO',
      'tipo_id': 129,
      'tipo': {
        'nombre': 'Licencia por Estudio',
        'codigo': '29',
        'columna_ficha': 'ESTUDIO'
      },
      'desde': '2026-12-30',
      'hasta': '2027-01-06',
      'dias': 5,
      'dias_calendario': 8,
      'dias_por_anio': {'2026': 2, '2027': 3},
    });
    expect(estudio.dias, 5);
    expect(estudio.diasCalendario, 8);
    expect(estudio.unidadDias, 'días hábiles');
    expect(resumirLicencias([estudio], 2026).single.dias, 2);
    expect(resumirLicencias([estudio], 2027).single.dias, 3);
  });

  late FichaPrintingFake printing;
  late PrintingPlatform original;
  setUp(() {
    original = PrintingPlatform.instance;
    printing = FichaPrintingFake();
    PrintingPlatform.instance = printing;
  });
  tearDown(() => PrintingPlatform.instance = original);
  test('resumen anual reparte días entre años y excluye anulaciones', () {
    final rows = [
      registro(),
      registro(id: 2, anulado: true),
      registro(id: 3, desde: DateTime(2025, 1, 1), hasta: DateTime(2025, 1, 3))
    ];
    final actual = resumirLicencias(rows, 2026).single;
    final siguiente = resumirLicencias(rows, 2027).single;
    expect(actual.registros, 1);
    expect(actual.dias, 2);
    expect(siguiente.dias, 2);
    expect(resumirLicencias([], 2026), isEmpty);
  });

  Future<void> mount(WidgetTester tester,
      {bool leer = true,
      Size size = const Size(1400, 950),
      List<LicenciaRegistro>? rows}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(overrides: [
      puedeLeerFichaProvider.overrideWith((ref) async => leer),
      fichaPersonasProvider.overrideWith((ref, buscar) async => [
            FichaPersona(
                dni: 12345678,
                nombre: 'PERSONA UNO',
                legajo: 10,
                reloj: 1010,
                fechaIngreso: DateTime(2015, 3, 2),
                carrera: 'Carrera de prueba'),
            const FichaPersona(
                dni: 23456789, nombre: 'PERSONA DOS', legajo: 11),
          ]),
      fichaLicenciasProvider.overrideWith((ref, consulta) async =>
          consulta.dni == 12345678
              ? rows ?? [registro(), registro(id: 2, anulado: true)]
              : []),
      fichaLicenciasAcumuladasProvider.overrideWith((ref, dni) async =>
          dni == 12345678
              ? rows ?? [registro(), registro(id: 2, anulado: true)]
              : []),
    ], child: const MaterialApp(home: Scaffold(body: FichaPage()))));
    await tester.pumpAndSettle();
  }

  testWidgets('sin permiso no muestra personas ni historial', (tester) async {
    await mount(tester, leer: false);
    expect(find.text('Sin permiso para consultar fichas.'), findsOneWidget);
    expect(find.text('PERSONA UNO'), findsNothing);
  });

  testWidgets('Ficha consulta por persona y no ofrece cargar ni modificar',
      (tester) async {
    await mount(tester);
    await tester.tap(find.text('PERSONA UNO'));
    await tester.pumpAndSettle();
    expect(find.text('Vista preliminar'), findsOneWidget);
    expect(find.byType(PdfPreview), findsOneWidget);
    expect(printing.impresiones, 0);
    await tester.tap(find.text('Datos e historial'));
    await tester.pumpAndSettle();
    expect(find.text('2 días en 2026'), findsOneWidget);
    expect(find.text('1 licencias registradas'), findsOneWidget);
    expect(find.text('Carrera de prueba'), findsOneWidget);
    expect(find.text('Datos laborales actuales'), findsOneWidget);
    expect(find.text('1010'), findsOneWidget);
    expect(find.text('02/03/2015'), findsOneWidget);
    expect(find.text('Guardar'), findsNothing);
    expect(find.text('Cargar licencia'), findsNothing);
    expect(find.byTooltip('Modificar licencia'), findsNothing);
    await tester.tap(find.text('PERSONA DOS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Datos e historial'));
    await tester.pumpAndSettle();
    expect(find.text('0 días en 2026'), findsOneWidget);
    expect(
        find.text(
            'No hay licencias registradas para esta persona en el año seleccionado.'),
        findsOneWidget);
  });

  testWidgets('la consulta funciona en una ventana compacta', (tester) async {
    await mount(tester, size: const Size(700, 900));
    await tester.tap(find.text('PERSONA UNO'));
    await tester.pumpAndSettle();
    expect(find.text('Vista preliminar'), findsOneWidget);
    expect(find.byType(PdfPreview), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Datos e historial'));
    await tester.pumpAndSettle();
    expect(find.text('2 días en 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'la planilla acumulada muestra todas las hojas y permite ampliar el mismo año sin imprimir',
      (tester) async {
    await mount(tester, rows: [
      registro(),
      for (var i = 0; i < 21; i++)
        registro(
            id: i + 2,
            desde: DateTime(2027, 1, i + 1),
            hasta: DateTime(2027, 1, i + 1))
    ]);
    await tester.tap(find.text('PERSONA UNO'));
    await tester.pumpAndSettle();
    expect(printing.paginas, 2);
    final preview = tester.widget<PdfPreview>(find.byType(PdfPreview));
    expect(preview.useActions, isFalse);
    expect(preview.allowPrinting, isFalse);
    await tester.tap(find.byType(DropdownButton<bool>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Solo 2026').last);
    await tester.pumpAndSettle();
    expect(printing.paginas, 1);
    await tester.tap(find.text('Ampliar / imprimir'));
    await tester.pumpAndSettle();
    expect(find.text('Ficha de registro de licencias'), findsOneWidget);
    final scope = tester.widget<DropdownButton<bool>>(find.descendant(
        of: find.byType(Dialog), matching: find.byType(DropdownButton<bool>)));
    expect(scope.value, isFalse);
    expect(printing.paginas, 1);
    expect(printing.impresiones, 0);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PERSONA DOS'));
    await tester.pumpAndSettle();
    expect(printing.paginas, 1);
    expect(String.fromCharCodes(printing.documentos.last), contains('(DOS)'));
    expect(String.fromCharCodes(printing.documentos.last),
        isNot(contains('(UNO)')));
    expect(tester.takeException(), isNull);
  });
}

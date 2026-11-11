import 'package:app_horas/features/licencias/application/licencias_providers.dart';
import 'package:app_horas/features/licencias/data/licencias_export.dart';
import 'package:app_horas/features/licencias/data/licencias_repository.dart';
import 'package:app_horas/features/licencias/domain/licencia.dart';
import 'package:app_horas/features/licencias/presentation/licencias_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _registro = LicenciaRegistro(
  id: 1,
  dni: 12345678,
  nombre: 'PRUEBA LICENCIAS',
  tipoId: 6,
  tipo: 'Lic. Anual',
  desde: DateTime(2026, 12, 30),
  hasta: DateTime(2027, 1, 2),
  dias: 4,
  origenFila: 2,
);

void main() {
  test(
      'la marca de documentación es explícita y la exportación no la presenta como vigente',
      () {
    final datos = <String, dynamic>{
      'id': 500,
      'dni': 12345678,
      'apellido_nombre': 'PERSONA DEMO',
      'tipo_id': 16,
      'tipo': {'nombre': 'Lic. Gremial'},
      'desde': '2026-04-09',
      'hasta': '2026-04-09',
      'dias': 1,
      'numero_orden': null,
    };
    final normal = LicenciaRegistro.fromJson(datos);
    final pendiente =
        LicenciaRegistro.fromJson({...datos, 'documentacion_pendiente': true});
    final anulada = LicenciaRegistro.fromJson({
      ...datos,
      'documentacion_pendiente': true,
      'anulado_at': '2026-11-10'
    });
    expect(normal.documentacionPendiente, isFalse);
    expect(normal.estado, 'Vigente');
    expect(pendiente.estado, 'Documentación pendiente');
    expect(anulada.estado, 'Anulada');
    final rows = buildLicenciasExcel([normal, pendiente])['Licencias'].rows;
    expect(rows[1][10]?.value.toString(), 'Vigente');
    expect(rows[2][10]?.value.toString(), 'Documentación pendiente');
    expect(rows[2][12]?.value.toString() ?? '', isEmpty);
    expect(rows[2][14]?.value, isNull);
  });
  test('días inclusivos y fecha final atraviesan años y febrero bisiesto', () {
    expect(diasLicencia(DateTime(2026, 12, 30), DateTime(2027, 1, 2)), 4);
    expect(diasLicencia(DateTime(2028, 2, 28), DateTime(2028, 3, 1)), 3);
    expect(diasLicencia(DateTime(2026, 1, 1, 23), DateTime(2026, 1, 1)), 1);
    expect(hastaLicencia(DateTime(2026, 12, 30), 4), DateTime(2027, 1, 2));
  });

  test(
      'exportación conserva todos los registros y los campos originales del informe',
      () {
    final excel = buildLicenciasExcel(List.filled(1501, _registro));
    final rows = excel['Licencias'].rows;
    expect(rows.length, 1502);
    expect(rows.first.take(6).map((c) => c?.value.toString()).toList(),
        ['DNI', 'Apellido y Nombre', 'Licencia', 'Desde', 'Hasta', 'Cant']);
    expect(rows.last[0]?.value.toString(), '12345678');
    expect(rows.last[3]?.value.toString(), '30/12/2026');
    expect(rows.last[5]?.value.toString(), '4');
    expect(excel.encode(), isNotEmpty);
  });

  Future<void> mount(WidgetTester tester, LicenciasPermisos permisos,
      {LicenciasRepository? repository,
      List<LicenciaRegistro>? registros,
      List<LicenciaTipo>? tipos}) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(overrides: [
      licenciasPermisosProvider.overrideWith((ref) async => permisos),
      licenciasAnioProvider.overrideWith((ref) => 2026),
      licenciasRegistrosProvider
          .overrideWith((ref) async => registros ?? [_registro]),
      licenciasTiposProvider.overrideWith((ref) async =>
          tipos ?? [const LicenciaTipo(id: 6, nombre: 'Lic. Anual')]),
      licenciasPendientesProvider.overrideWith((ref) async => []),
      licenciasImportadasResumenProvider.overrideWith((ref) async => []),
      licenciasPersonasProvider.overrideWith((ref, buscar) async =>
          [const LicenciaPersona(dni: 12345678, nombre: 'PRUEBA LICENCIAS')]),
      if (repository != null)
        licenciasRepoProvider.overrideWithValue(repository),
    ], child: const MaterialApp(home: Scaffold(body: LicenciasPage()))));
    await tester.pumpAndSettle();
  }

  testWidgets('sin lectura no expone historial ni carga', (tester) async {
    await mount(tester, const LicenciasPermisos());
    expect(find.text('Sin permiso para consultar licencias.'), findsOneWidget);
    expect(find.text('PRUEBA LICENCIAS'), findsNothing);
    expect(find.text('Cargar licencia'), findsNothing);
  });

  testWidgets('consulta sin botones de escritura; búsqueda y filtros',
      (tester) async {
    await mount(tester, const LicenciasPermisos(leer: true));
    expect(find.text('PRUEBA LICENCIAS'), findsOneWidget);
    expect(find.text('Cargar licencia'), findsNothing);
    expect(find.byTooltip('Modificar licencia'), findsNothing);
    expect(find.byTooltip('Anular licencia'), findsNothing);
    await tester.enterText(find.byType(TextField).first, '12.345.678 prueba');
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('PRUEBA LICENCIAS'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'inexistente');
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('No hay licencias para estos filtros.'), findsOneWidget);
  });

  testWidgets('carga conserva el cálculo hasta e impide guardar doble',
      (tester) async {
    final repo = _RecordingRepository();
    addTearDown(() {
      repo.sb.dispose();
    });
    await mount(tester, const LicenciasPermisos(leer: true, cargar: true),
        repository: repo);
    await tester.tap(find.text('Cargar licencia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PRUEBA LICENCIAS').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lic. Anual').last);
    await tester.pumpAndSettle();
    final dias = find.widgetWithText(TextFormField, 'Cantidad de días');
    await tester.enterText(dias, '4');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(repo.calls, 1);
    expect(diasLicencia(repo.desde!, repo.hasta!), 4);
    expect(find.text('Licencia guardada'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('filtro Familiar agrupa 10, 11 y el histórico pendiente',
      (tester) async {
    LicenciaRegistro familiar(int id, int tipoId, String? codigo) =>
        LicenciaRegistro.fromJson({
          'id': id,
          'dni': 12345678,
          'apellido_nombre': 'FAMILIAR $id',
          'tipo_id': tipoId,
          'categoria_excel_id': 3,
          'tipo': {'nombre': 'Cuidado de Fliar. Enfermo', 'codigo': codigo},
          'desde': '2026-07-01',
          'hasta': '2026-07-01',
          'dias': 1,
        });
    await mount(tester, const LicenciasPermisos(leer: true), registros: [
      familiar(10, 110, '10'),
      familiar(11, 111, '11'),
      familiar(3, 3, null),
      _registro,
    ], tipos: [
      const LicenciaTipo(
          id: 110,
          nombre: 'Cuidado de Fliar. Enfermo',
          codigo: '10',
          categoriaExcelId: 3),
      const LicenciaTipo(
          id: 111,
          nombre: 'Cuidado de Fliar. Enfermo',
          codigo: '11',
          categoriaExcelId: 3),
      const LicenciaTipo(
          id: 101, nombre: 'Lic. Anual', codigo: '01', categoriaExcelId: 6),
    ]);
    await tester.tap(find.byType(DropdownButtonFormField<int>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cuidado de Fliar. Enfermo').last);
    await tester.pumpAndSettle();
    expect(find.text('3 registros · 3 días registrados'), findsOneWidget);
    expect(find.text('FAMILIAR 10'), findsOneWidget);
    expect(find.text('FAMILIAR 11'), findsOneWidget);
    expect(find.text('FAMILIAR 3'), findsOneWidget);
    expect(find.text('PRUEBA LICENCIAS'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('imprevisto conserva orden y se administra desde su módulo',
      (tester) async {
    final imprevisto = LicenciaRegistro.fromJson({
      'id': -42,
      'imprevisto_id': 42,
      'dni': 12345678,
      'apellido_nombre': 'PRUEBA IMPREVISTO',
      'tipo_id': 143,
      'tipo': {'nombre': 'Imprevisto', 'codigo': '43', 'columna_ficha': 'ART8'},
      'desde': '2026-07-01',
      'hasta': '2026-07-01',
      'dias': 1,
      'numero_orden': 321,
    });
    expect(imprevisto.esImprevisto, isTrue);
    expect(imprevisto.numeroOrden, 321);
    await mount(tester,
        const LicenciasPermisos(leer: true, cargar: true, administrar: true),
        registros: [imprevisto]);
    expect(find.text('43 · Imprevisto'), findsOneWidget);
    expect(find.text('Gestionar en Imprevistos'), findsOneWidget);
    expect(find.byTooltip('Modificar licencia'), findsNothing);
    expect(find.byTooltip('Anular licencia'), findsNothing);
    final tooltip = tester.widget<Tooltip>(find
        .ancestor(
            of: find.text('PRUEBA IMPREVISTO'), matching: find.byType(Tooltip))
        .first);
    expect(tooltip.message, contains('N.º de orden: 321'));
  });

  testWidgets('la carga de licencias dirige Art. 8 a Imprevistos',
      (tester) async {
    await mount(tester, const LicenciasPermisos(leer: true, cargar: true),
        tipos: [
          const LicenciaTipo(id: 101, nombre: 'Anual', codigo: '01'),
          const LicenciaTipo(id: 143, nombre: 'Imprevisto', codigo: '43'),
          const LicenciaTipo(
              id: 198, nombre: 'Imprevisto siguiente', codigo: '98'),
        ]);
    await tester.tap(find.text('Cargar licencia'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).last);
    await tester.pumpAndSettle();
    expect(find.text('01 · Anual'), findsWidgets);
    expect(find.text('43 · Imprevisto'), findsNothing);
    expect(find.text('98 · Imprevisto siguiente'), findsNothing);
    expect(
        find.text(
            'Los imprevistos se cargan y modifican desde el módulo Imprevistos.'),
        findsOneWidget);
  });

  testWidgets('Estudio pide hábiles y usa hasta calculado por el servidor',
      (tester) async {
    final repo = _RecordingRepository();
    addTearDown(() async {
      await tester.runAsync(repo.sb.dispose);
    });
    await mount(tester, const LicenciasPermisos(leer: true, cargar: true),
        repository: repo,
        tipos: [
          const LicenciaTipo(
              id: 129,
              nombre: 'Licencia por Estudio',
              codigo: '29',
              columnaFicha: 'ESTUDIO')
        ]);
    await tester.tap(find.text('Cargar licencia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PRUEBA LICENCIAS').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('29 · Licencia por Estudio').last);
    await tester.pumpAndSettle();
    final campo = find.widgetWithText(TextFormField, 'Días hábiles (máx. 5)');
    await tester.enterText(campo, '6');
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar'))
            .onPressed,
        isNull);
    await tester.enterText(campo, '5');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(repo.calls, 1);
    expect(repo.solicitudHabiles, 5);
    expect(repo.hasta, DateTime(2026, 11, 10));
    await tester.pump(const Duration(seconds: 4));
  });
}

class _RecordingRepository extends LicenciasRepository {
  _RecordingRepository() : super(_ClientDePrueba());
  int calls = 0;
  DateTime? desde;
  DateTime? hasta;
  int? solicitudHabiles;
  @override
  Future<DateTime> hastaEstudio(DateTime desde, int dias) async {
    solicitudHabiles = dias;
    return DateTime(2026, 11, 10);
  }

  @override
  Future<void> guardar(
      {int? id,
      required int dni,
      required int tipoId,
      required DateTime desde,
      required DateTime hasta,
      String? observacion,
      int? dniFamiliar,
      int? numeroOrden,
      String? cantidadFicha}) async {
    calls++;
    this.desde = desde;
    this.hasta = hasta;
  }
}

class _ClientDePrueba implements SupabaseClient {
  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('La prueba no usa la conexión Supabase.');
}

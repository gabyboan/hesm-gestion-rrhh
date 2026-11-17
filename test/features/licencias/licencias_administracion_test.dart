import 'package:app_horas/core/cache/session_cache_provider.dart';
import 'package:app_horas/core/cache/session_data_cache.dart';
import 'package:app_horas/features/ficha/application/ficha_providers.dart';
import 'package:app_horas/features/ficha/domain/ficha_persona.dart';
import 'package:app_horas/features/ficha/presentation/ficha_page.dart';
import 'package:app_horas/features/licencias/application/licencias_providers.dart';
import 'package:app_horas/features/licencias/data/licencias_repository.dart';
import 'package:app_horas/features/licencias/domain/licencia.dart';
import 'package:app_horas/features/licencias/presentation/licencias_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/src/interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../ficha/ficha_printing_fake.dart';

void main() {
  late _Repository repo;
  late PrintingPlatform original;
  setUp(() {
    repo = _Repository();
    original = PrintingPlatform.instance;
    PrintingPlatform.instance = FichaPrintingFake();
  });
  tearDown(() => PrintingPlatform.instance = original);

  Future<void> mount(WidgetTester tester, bool ficha,
      {bool admin = true}) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionDataCacheProvider.overrideWith((ref) {
            final cache = SessionDataCache();
            ref.onDispose(cache.dispose);
            return cache;
          }),
          licenciasRepoProvider.overrideWithValue(repo),
          licenciasPermisosProvider.overrideWith(
              (ref) async => LicenciasPermisos(leer: true, administrar: admin)),
          licenciasAnioProvider.overrideWith((ref) => DateTime.now().year),
          licenciasRegistrosProvider.overrideWith((ref) async => repo.rows),
          licenciasTiposProvider.overrideWith((ref) async => [
                const LicenciaTipo(id: 101, nombre: 'Lic. Anual', codigo: '01')
              ]),
          licenciasPendientesProvider.overrideWith((ref) async => []),
          licenciasImportadasResumenProvider.overrideWith((ref) async => []),
          puedeLeerFichaProvider.overrideWith((ref) async => true),
          fichaPersonasProvider.overrideWith((ref, q) async =>
              [const FichaPersona(dni: 12345678, nombre: 'AGENTE DEMO')]),
          fichaLicenciasProvider
              .overrideWith((ref, consulta) async => repo.rows),
          fichaLicenciasAcumuladasProvider
              .overrideWith((ref, dni) async => repo.rows),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: ficha ? const FichaPage() : const LicenciasPage()))));
    await tester.pumpAndSettle();
    if (ficha) {
      await tester.tap(find.text('AGENTE DEMO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Datos e historial'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
    }
  }

  Finder edit(bool ficha) => ficha
      ? find.text('Modificar licencia')
      : find.byTooltip('Modificar licencia');
  Finder borrar(bool ficha) =>
      ficha ? find.text('Borrar licencia') : find.byTooltip('Borrar licencia');

  for (final ficha in [false, true]) {
    final modulo = ficha ? 'Ficha' : 'Licencias';
    testWidgets('$modulo: lectura no habilita edición ni borrado',
        (tester) async {
      await mount(tester, ficha, admin: false);
      expect(edit(ficha), findsNothing);
      expect(borrar(ficha), findsNothing);
    });

    testWidgets(
        '$modulo: editar conserva el período original de una ficha de papel',
        (tester) async {
      await mount(tester, ficha);
      await tester.tap(edit(ficha));
      await tester.pumpAndSettle();
      final dias = find.widgetWithText(TextFormField, 'Días hábiles');
      expect(tester.widget<TextFormField>(dias).controller!.text, '15');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(repo.guardadoId, 11);
      expect(repo.hasta, DateTime(DateTime.now().year, 1, 19));
      expect(find.text('Licencia modificada'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets(
        '$modulo: cancelar no borra y confirmar actualiza historial y totales',
        (tester) async {
      await mount(tester, ficha);
      await tester.tap(borrar(ficha));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(repo.borrados, isEmpty);
      await tester.tap(borrar(ficha));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
      await tester.pumpAndSettle();
      expect(repo.borrados, [11]);
      expect(find.text('Licencia borrada'), findsOneWidget);
      if (ficha) {
        expect(find.text('0 días en ${DateTime.now().year}'), findsOneWidget);
        expect(find.text('0 licencias registradas'), findsOneWidget);
      } else {
        expect(
            find.text('No hay licencias para estos filtros.'), findsOneWidget);
      }
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('$modulo: un borrado rechazado conserva el registro',
        (tester) async {
      repo.rechazar = true;
      await mount(tester, ficha);
      await tester.tap(borrar(ficha));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
      await tester.pumpAndSettle();
      expect(repo.borrados, isEmpty);
      expect(find.textContaining('La licencia ya no está disponible.'),
          findsOneWidget);
      expect(borrar(ficha), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });
  }
}

class _Repository extends LicenciasRepository {
  _Repository() : super(_Client());
  final borrados = <int>[];
  bool rechazar = false;
  int? guardadoId;
  DateTime? hasta;
  List<LicenciaRegistro> get rows => borrados.isNotEmpty
      ? []
      : [
          LicenciaRegistro(
            id: 11,
            dni: 12345678,
            nombre: 'AGENTE DEMO',
            tipoId: 101,
            tipo: 'Lic. Anual',
            codigo: '01',
            desde: DateTime(DateTime.now().year, 1, 1),
            hasta: DateTime(DateTime.now().year, 1, 19),
            dias: 15,
            diasCalendario: 19,
            cantidadDiasFicha: 15,
            cantidadFicha: '15/25',
          )
        ];

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
    guardadoId = id;
    this.hasta = hasta;
  }

  @override
  Future<bool> anular(int id) async {
    if (rechazar) return false;
    borrados.add(id);
    return true;
  }
}

class _Client implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

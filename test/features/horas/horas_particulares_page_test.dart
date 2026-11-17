import 'package:app_horas/core/cache/session_cache_provider.dart';
import 'package:app_horas/core/cache/session_data_cache.dart';
import 'package:app_horas/features/horas/application/horas_providers.dart';
import 'package:app_horas/features/horas/data/horas_repository.dart';
import 'package:app_horas/features/horas/domain/hora_registro.dart';
import 'package:app_horas/features/horas/domain/persona.dart';
import 'package:app_horas/features/horas/presentation/cargar/cargar_horas_page.dart';
import 'package:app_horas/features/horas/presentation/ver/ver_horas_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const persona = Persona(
  apellido: 'Prueba',
  nombre: 'Ana',
  dni: 1001,
  carreraId: 1,
  carrera: 'Titulares',
);

class _HorasEnMemoria implements HorasRepository {
  final rows = <HoraRegistro>[];
  bool fallaConsulta = false;

  @override
  Future<List<HoraRegistro>> registrosMes({
    required int dni,
    required int carreraId,
    required DateTime periodo,
  }) async {
    if (fallaConsulta) throw StateError('Consulta no disponible');
    return rows
        .where((r) =>
            r.dni == dni &&
            r.carreraId == carreraId &&
            r.periodo.year == periodo.year &&
            r.periodo.month == periodo.month)
        .toList();
  }

  @override
  Future<void> cargarHora({
    String? operacionId,
    required int dni,
    required int carreraId,
    required DateTime fecha,
    required String tipoDb,
    int? minutos,
  }) async {
    rows.add(HoraRegistro.fromJson({
      'id': rows.length + 1,
      'dni': dni,
      'carrera_id': carreraId,
      'fecha': fecha.toIso8601String(),
      'periodo': DateTime(fecha.year, fecha.month).toIso8601String(),
      'tipo': tipoDb,
      'minutos': minutos,
    }));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container(_HorasEnMemoria repository) {
  final container = ProviderContainer(overrides: [
    horasRepoProvider.overrideWithValue(repository),
    sessionDataCacheProvider.overrideWithValue(SessionDataCache()),
    listadoProvider.overrideWith((ref) async => [persona]),
    // La misma persona puede cargar tanto particulares como oficiales.
    listadoOficialesProvider.overrideWith((ref) async => [persona]),
  ]);
  container.read(selectedPersonaProvider.notifier).state = persona;
  container.read(fechaProvider.notifier).state = DateTime(2026, 11, 16);
  container.read(periodoProvider.notifier).state = DateTime(2026, 10);
  return container;
}

Widget _app(ProviderContainer container, Widget page) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: page)),
    );

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('avisa, guarda excedentes y los muestra completos en Ver',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _HorasEnMemoria();
    for (var i = 0; i < 6; i++) {
      await repository.cargarHora(
        dni: persona.dni,
        carreraId: persona.carreraId,
        fecha: DateTime(2026, 11, i + 1),
        tipoDb: 'PARTICULAR',
        minutos: 30,
      );
    }
    final container = _container(repository);
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container, const CargarHorasPage()));
    await tester.pumpAndSettle();
    expect(
        find.text('Cargadas: 3:00 h · Cupo mensual: 3:00 h'), findsOneWidget);
    // Consulta noviembre aunque Ver estaba en octubre.
    await tester.tap(find.widgetWithText(ChoiceChip, '30 minutos'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Límite mensual excedido en 0:30 h'),
        findsOneWidget);
    expect(find.text('Total con esta carga: 3:30 h'), findsOneWidget);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(repository.rows, hasLength(7));
    expect(repository.rows.last.minutos, 30);
    expect(container.read(periodoProvider), DateTime(2026, 11));
    expect(
        find.text('Cargadas: 3:30 h · Cupo mensual: 3:00 h'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '30 minutos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(repository.rows, hasLength(8));
    // Esperar el cartel de éxito antes de desmontar su overlay.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(_app(container, const VerHorasPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Particulares 4:00 h'), findsOneWidget);
    expect(find.text('Horas particulares disponibles: Excedido 1:00'),
        findsOneWidget);
    expect(find.textContaining('Excedido: 0:30'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('alcanzar exactamente el cupo no muestra excedente',
      (tester) async {
    final container = _container(_HorasEnMemoria());
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container, const CargarHorasPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '3 horas'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Límite mensual excedido'), findsNothing);
    expect(find.text('Total con esta carga: 3:00 h'), findsOneWidget);
  });

  testWidgets('un fallo de consulta avisa y permite guardar', (tester) async {
    final repository = _HorasEnMemoria()..fallaConsulta = true;
    final container = _container(repository);
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container, const CargarHorasPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('No se pudo consultar el total mensual.'),
        findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '30 minutos'));
    await tester.pumpAndSettle();
    final guardar = find.text('Guardar');
    await tester.scrollUntilVisible(guardar, 250);
    await tester.tap(guardar);
    await tester.pumpAndSettle();
    expect(repository.rows, hasLength(1));
    await tester.pump(const Duration(seconds: 4));
  });
}

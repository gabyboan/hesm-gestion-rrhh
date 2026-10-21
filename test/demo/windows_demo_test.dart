import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_horas/core/supabase/supabase_provider.dart';
import 'package:app_horas/features/horas/application/horas_providers.dart';
import 'package:app_horas/features/medicos/application/cola_impresion_provider.dart';
import 'package:app_horas/features/preferences/application/user_preferences_providers.dart';
import 'package:app_horas/features/preferences/domain/user_preferences.dart';
import 'package:app_horas/features/shell/presentation/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/demo/main.dart';

class _Raster extends PdfRaster {
  _Raster() : super(1, 1, Uint8List.fromList([255, 255, 255, 255]));
  @override
  Future<Uint8List> toPng() async => base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=');
}

class _Preview extends PrintingPlatform {
  @override
  Future<PrintingInfo> info() async => const PrintingInfo(canRaster: true);
  @override
  Stream<PdfRaster> raster(
      Uint8List document, List<int>? pages, double dpi) async* {
    yield _Raster();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Native printing is disabled during tests.');
}

void main() {
  late PrintingPlatform original;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    original = PrintingPlatform.instance;
    PrintingPlatform.instance = _Preview();
  });
  tearDown(() => PrintingPlatform.instance = original);

  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const DemoApp());
    await tester.pumpAndSettle();
  }

  testWidgets('demo recorre los módulos y bloquea escrituras y datos reales',
      (tester) async {
    await open(tester);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(MainShell)));
    expect(() => container.read(supabaseClientProvider), throwsStateError);
    await tester.tap(find.text('Horas').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Cuenta DEMO'), findsWidgets);
    await tester.tap(find.text('Informe').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
        container.read(cargarHoraControllerProvider.notifier).submit(),
        throwsUnsupportedError);
    await expectLater(
        container.read(borrarHoraControllerProvider.notifier).borrar(1),
        throwsUnsupportedError);
    await tester.tap(find.byTooltip('Módulos'));
    await tester.pumpAndSettle();
    for (final module in ['Francos', 'Imprevisto', 'Médicos', 'Suplencias']) {
      await tester.tap(find.text(module).first);
      await tester.pumpAndSettle();
      if (module == 'Francos') {
        await tester.enterText(find.byType(TextField).first, 'persona 2');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(find.textContaining('Persona 1'), findsNothing);
        expect(find.textContaining('Persona 2'), findsWidgets);
      }
      if (module == 'Médicos') {
        await tester.tap(find.text('Partes registrados'));
        await tester.pumpAndSettle();
        await tester
            .tap(find.byTooltip('Agregar a la bandeja de impresión').first);
        await tester.pumpAndSettle();
        expect(container.read(colaImpresionProvider), hasLength(1));
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: module);
      await tester.tap(find.byTooltip('Módulos'));
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('salir reinicia preferencias y bandeja de la demo',
      (tester) async {
    await open(tester);
    final initial =
        ProviderScope.containerOf(tester.element(find.byType(MainShell)));
    await initial.read(userPreferencesControllerProvider).save(
        const UserPreferences(themeMode: ThemeMode.light, idleMinutes: 2));
    await tester.pumpAndSettle();
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.light);
    await tester.tap(find.text('Médicos').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Partes registrados'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Agregar a la bandeja de impresión').first);
    await tester.pumpAndSettle();
    expect(initial.read(colaImpresionProvider), hasLength(1));
    await tester.tap(find.byTooltip('Módulos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Salir'));
    await tester.pumpAndSettle();
    final restarted =
        ProviderScope.containerOf(tester.element(find.byType(MainShell)));
    expect(identical(initial, restarted), isFalse);
    expect(restarted.read(colaImpresionProvider), isEmpty);
    expect(await restarted.read(userPreferencesProvider.future),
        UserPreferences.defaults);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('la política de red de la demo impide crear clientes HTTP', () {
    HttpOverrides.runWithHttpOverrides(() {
      expect(() => HttpClient(), throwsUnsupportedError);
    }, DemoNetworkDisabled());
  });
}

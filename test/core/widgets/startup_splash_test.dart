import 'dart:math' as math;

import 'package:app_horas/core/startup/startup_checks.dart';
import 'package:app_horas/core/widgets/startup_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('centra la marca, la sube y habilita los controles una sola vez',
      (tester) async {
    var ready = 0;
    Widget splash() => MaterialApp(
            home: StartupSplash(onReady: () => ready++, checks: const [
          StartupCheckState(StartupCheck.dns, CheckStatus.pending)
        ]));
    await tester.pumpWidget(splash());
    final initial = tester.getRect(find.byType(HesmAnimatedMark));
    expect(initial.width, closeTo(128, 0.01));
    expect(ready, 0);
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.getRect(find.byType(HesmAnimatedMark)), initial);
    await tester.pump(const Duration(milliseconds: 1400));
    expect(ready, 1);
    final compact = tester.getRect(find.byType(HesmAnimatedMark));
    expect(compact.width, closeTo(76.8, 0.01));
    expect(compact.top, lessThan(initial.top));
    expect(compact.bottom,
        lessThan(tester.getRect(find.text('Resolución DNS')).top));
    expect(find.text('En espera').hitTestable(), findsOneWidget);
    await tester.pumpWidget(splash());
    await tester.pump(const Duration(seconds: 3));
    expect(ready, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('respeta movimiento reducido y muestra el resultado completo',
      (tester) async {
    var ready = 0;
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: StartupSplash(onReady: () => ready++, checks: [
              for (final check in StartupCheck.values)
                StartupCheckState(check, CheckStatus.passed)
            ]))));
    await tester.pump();
    expect(ready, 1);
    expect(tester.getRect(find.byType(HesmAnimatedMark)).width,
        closeTo(76.8, 0.01));
    expect(tester.widget<HesmMark>(find.byType(HesmMark)).rotation, 0);
    await tester.ensureVisible(find.text('6 de 6'));
    expect(
        find.text('Todo listo. Ingresando...').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra la identidad y mantiene el engranaje animado', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: StartupSplash()),
    );

    expect(find.text('HESM'), findsOneWidget);
    expect(find.text('GESTIÓN RRHH'), findsOneWidget);
    expect(find.text('Preparando tu espacio de trabajo...'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 900));

    expect(tester.takeException(), isNull);
  });

  testWidgets('arranca lento, acelera, frena y retrocede un diente',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StartupSplash()));
    double angulo() => tester.widget<HesmMark>(find.byType(HesmMark)).rotation;
    await tester.pump(const Duration(milliseconds: 200));
    final lentoInicio = angulo();
    await tester.pump(const Duration(milliseconds: 100));
    final avanceLento = angulo() - lentoInicio;
    await tester.pump(const Duration(milliseconds: 2700));
    final rapidoInicio = angulo();
    await tester.pump(const Duration(milliseconds: 100));
    final avanceRapido = angulo() - rapidoInicio;
    expect(avanceLento, greaterThan(0));
    expect(avanceRapido, greaterThan(avanceLento));

    await tester.pump(const Duration(milliseconds: 3200));
    final frenandoInicio = angulo();
    await tester.pump(const Duration(milliseconds: 100));
    final avanceFrenando = angulo() - frenandoInicio;
    expect(avanceFrenando, greaterThan(0));
    expect(avanceFrenando, lessThan(avanceRapido));

    await tester.pump(const Duration(milliseconds: 400));
    final antesDeVolver = angulo();
    await tester.pump(const Duration(milliseconds: 800));
    expect(antesDeVolver - angulo(), closeTo(math.pi / 4, 0.001));
  });
}

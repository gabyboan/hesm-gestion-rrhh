import 'dart:math' as math;

import 'package:app_horas/core/widgets/startup_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

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
}

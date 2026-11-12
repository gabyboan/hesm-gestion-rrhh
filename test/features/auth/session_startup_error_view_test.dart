import 'package:app_horas/core/startup/backend_capabilities.dart';
import 'package:app_horas/features/auth/presentation/session_startup_error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('base pendiente permite reintentar y volver al login',
      (tester) async {
    var retries = 0;
    var exits = 0;
    await tester.pumpWidget(MaterialApp(
        home: SessionStartupErrorView(
      error: const BackendUpdateRequired(),
      onRetry: () => retries++,
      onSignOut: () => exits++,
    )));
    expect(find.text('Actualización de la base pendiente'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.tap(find.text('Volver al inicio de sesión'));
    expect(retries, 1);
    expect(exits, 1);
  });

  testWidgets(
      'errores internos no se muestran y salida pendiente bloquea acciones',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: SessionStartupErrorView(
      error: StateError('respuesta interna confidencial'),
      busy: true,
      onRetry: () => fail('No debe reintentar mientras sale'),
      onSignOut: () => fail('No debe duplicar la salida'),
    )));
    expect(find.textContaining('confidencial'), findsNothing);
    expect(find.text('No se pudo abrir la sesión'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.byWidgetPredicate((widget) => widget is FilledButton))
            .onPressed,
        isNull);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull);
  });
}

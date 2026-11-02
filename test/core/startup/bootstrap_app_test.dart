import 'package:app_horas/core/startup/startup_checks.dart';
import 'package:app_horas/core/startup/startup_config.dart';
import 'package:app_horas/core/widgets/startup_splash.dart';
import 'package:app_horas/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'startup_checks_test.dart' show FakeStartupNetwork;

void main() {
  testWidgets('never reaches login on failure and can recover with Retry',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final network = FakeStartupNetwork()..failAt = StartupCheck.dns;
    final checks = StartupChecks(
        network: network,
        ensureInstance: () async {},
        loadConfig: () async => StartupConfig.validate(
            'https://example.org', 'sb_publishable_test_client_key'),
        prepareApplication: (_) async {});
    await tester.pumpWidget(BootstrapApp(
        args: const [],
        checks: checks,
        minimumSplashDuration: Duration.zero,
        application:
            const MaterialApp(home: Scaffold(body: Text('LOGIN DISPONIBLE')))));
    expect(network.calls, isEmpty);
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump();
    expect(find.text('LOGIN DISPONIBLE'), findsNothing);
    expect(find.text('No podemos continuar con el inicio.'), findsOneWidget);
    expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(tester.getCenter(find.byType(HesmAnimatedMark)).dy,
        lessThan(tester.getCenter(find.text('Resolución DNS')).dy));
    network.failAt = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();
    expect(find.text('LOGIN DISPONIBLE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('failure remains readable on small screens with large text',
      (tester) async {
    tester.view.physicalSize = const Size(480, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.7)),
            child: StartupSplash(
              onRetry: () {},
              checks: [
                for (final check in StartupCheck.values)
                  StartupCheckState(
                      check,
                      check == StartupCheck.internet
                          ? CheckStatus.failed
                          : check.index < StartupCheck.internet.index
                              ? CheckStatus.passed
                              : CheckStatus.pending,
                      message: check == StartupCheck.internet
                          ? 'Revisá internet o la conexión de la red del hospital.'
                          : null)
              ],
            ))));
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.ensureVisible(find.text('Reintentar'));
    expect(find.text('Reintentar').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

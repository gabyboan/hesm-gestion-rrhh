import 'dart:async';

import 'package:app_horas/core/startup/startup_checks.dart';
import 'package:app_horas/core/startup/startup_config.dart';
import 'package:app_horas/core/updates/lan_release.dart';
import 'package:app_horas/core/updates/startup_update.dart';
import 'package:app_horas/core/widgets/startup_splash.dart';
import 'package:app_horas/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'startup_checks_test.dart' show FakeStartupNetwork;

const release = LanRelease(
    version: '1.0.5.6',
    fileName: 'HESM-Gestion-RRHH-1.0.5.6-Setup.exe',
    length: 1,
    sha256Hex: '',
    signature: '');

Widget bootstrap(Future<StartupUpdateState> Function() check,
    {FakeStartupNetwork? network}) {
  return BootstrapApp(
      args: const [],
      minimumSplashDuration: Duration.zero,
      checkUpdates: check,
      checks: StartupChecks(
          network: network ?? FakeStartupNetwork(),
          ensureInstance: () async {},
          loadConfig: () async => StartupConfig.validate(
              'https://example.org', 'sb_publishable_test_client_key'),
          prepareApplication: (_) async {}),
      application:
          const MaterialApp(home: Scaffold(body: Text('LOGIN DISPONIBLE'))));
}

void largeWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
      'checks once at startup and lets the user ignore a pending update',
      (tester) async {
    largeWindow(tester);
    final result = Completer<StartupUpdateState>();
    var calls = 0;
    await tester.pumpWidget(bootstrap(() {
      calls++;
      return result.future;
    }));
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump();
    expect(find.text('LOGIN DISPONIBLE'), findsNothing);
    expect(find.text('Actualizaciones del sistema'), findsOneWidget);
    result.complete(const StartupUpdateState(StartupUpdateStatus.available,
        release: release));
    await tester.pump();
    await tester.pump();
    expect(find.text('Actualización pendiente'), findsOneWidget);
    expect(find.text('Listo'), findsNothing);
    expect(find.text('LOGIN DISPONIBLE'), findsNothing);
    await tester.tap(find.text('Ignorar y continuar'));
    await tester.pump();
    expect(find.text('LOGIN DISPONIBLE'), findsOneWidget);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ignoring an update never bypasses a failed mandatory service',
      (tester) async {
    largeWindow(tester);
    final network = FakeStartupNetwork()..failAt = StartupCheck.dns;
    await tester.pumpWidget(bootstrap(
        () async => const StartupUpdateState(StartupUpdateStatus.available,
            release: release),
        network: network));
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump();
    expect(find.text('No podemos continuar con el inicio.'), findsOneWidget);
    expect(
        tester
            .widget<TextButton>(
                find.widgetWithText(TextButton, 'Ignorar y continuar'))
            .onPressed,
        isNull);
    expect(find.text('LOGIN DISPONIBLE'), findsNothing);
    network.failAt = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Ignorar y continuar'));
    await tester.pump();
    expect(find.text('LOGIN DISPONIBLE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a network share timeout lets healthy services reach login',
      (tester) async {
    largeWindow(tester);
    final never = Completer<StartupUpdateState>();
    await tester.pumpWidget(bootstrap(() => never.future));
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump();
    expect(find.text('LOGIN DISPONIBLE'), findsNothing);
    await tester.pump(const Duration(seconds: 12));
    await tester.pump();
    expect(find.text('LOGIN DISPONIBLE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unavailable update source does not report a service failure',
      (tester) async {
    largeWindow(tester);
    await tester.pumpWidget(bootstrap(() async => throw Exception('offline')));
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump();
    expect(find.text('LOGIN DISPONIBLE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the installed version and a seventh successful check',
      (tester) async {
    largeWindow(tester);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: StartupSplash(
                version: '1.0.4.5',
                updates: const StartupUpdateState(StartupUpdateStatus.current),
                checks: [
                  for (final check in StartupCheck.values)
                    StartupCheckState(check, CheckStatus.passed)
                ]))));
    await tester.pump();
    expect(find.text('v1.0.4.5'), findsOneWidget);
    expect(tester.getCenter(find.text('v1.0.4.5')).dx,
        greaterThan(tester.getCenter(find.byType(HesmAnimatedMark)).dx));
    expect(find.text('Sistema actualizado'), findsOneWidget);
    expect(find.text('7 de 7'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(7));
    expect(find.text('Listo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'version and pending update actions fit small windows and big text',
      (tester) async {
    tester.view.physicalSize = const Size(480, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var ignored = false;
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(
                textScaler: TextScaler.linear(1.7), disableAnimations: true),
            child: StartupSplash(
                version: '1.0.4.5',
                updates: const StartupUpdateState(StartupUpdateStatus.available,
                    release: release),
                onIgnoreUpdate: () => ignored = true,
                onInstallUpdate: () {},
                checks: [
                  for (final check in StartupCheck.values)
                    StartupCheckState(check, CheckStatus.passed)
                ]))));
    await tester.pump();
    await tester.ensureVisible(find.text('Ignorar y continuar'));
    await tester.tap(find.text('Ignorar y continuar'));
    expect(ignored, isTrue);
    expect(find.text('v1.0.4.5').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

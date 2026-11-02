// Captures the real startup widget with simulated results, without networking.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_horas/core/startup/startup_checks.dart';
import 'package:app_horas/core/updates/lan_release.dart';
import 'package:app_horas/core/updates/startup_update.dart';
import 'package:app_horas/core/widgets/startup_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('captures startup checks and blocking error', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      await (FontLoader('Roboto')
            ..addFont(File('C:/Windows/Fonts/segoeui.ttf')
                .readAsBytes()
                .then(ByteData.sublistView)))
          .load();
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
      await Directory('build/startup-preview').create(recursive: true);
    });
    for (final mode in ['checking', 'blocked', 'pending', 'updated']) {
      final blocked = mode == 'blocked';
      final pending = mode == 'pending';
      final allPassed = pending || mode == 'updated';
      final key = GlobalKey();
      final current = blocked ? StartupCheck.dns : StartupCheck.data;
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
              useMaterial3: true, colorSchemeSeed: const Color(0xFF045E63)),
          home: MediaQuery(
            data: const MediaQueryData(
                size: Size(1280, 760), disableAnimations: true),
            child: RepaintBoundary(
                key: key,
                child: StartupSplash(
                    onRetry: () {},
                    onInstallUpdate: () {},
                    onIgnoreUpdate: () {},
                    updates: mode == 'checking'
                        ? const StartupUpdateState(StartupUpdateStatus.checking)
                        : pending
                            ? const StartupUpdateState(
                                StartupUpdateStatus.available,
                                release: LanRelease(
                                    version: '1.0.5.6',
                                    fileName:
                                        'HESM-Gestion-RRHH-1.0.5.6-Setup.exe',
                                    length: 1,
                                    sha256Hex: '',
                                    signature: ''))
                            : const StartupUpdateState(
                                StartupUpdateStatus.current),
                    checks: [
                      for (final check in StartupCheck.values)
                        StartupCheckState(
                            check,
                            allPassed || check.index < current.index
                                ? CheckStatus.passed
                                : check == current
                                    ? blocked
                                        ? CheckStatus.failed
                                        : CheckStatus.running
                                    : CheckStatus.pending,
                            message: blocked && check == current
                                ? 'No se puede encontrar el servidor por su nombre. Revisá la red y el DNS del equipo.'
                                : null)
                    ])),
          )));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image = await (key.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('build/startup-preview/$mode.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}

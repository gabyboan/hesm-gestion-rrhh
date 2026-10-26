// Genera capturas de la interfaz real sin iniciar sesión ni acceder a la red.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_horas/features/auth/presentation/login_page.dart';
import 'package:app_horas/features/medicos/domain/parte_medico_qr.dart';
import 'package:app_horas/features/medicos/presentation/parte_medico_qr_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('genera login centrado y QR ampliado', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
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
      await Directory('build/login-preview').create(recursive: true);
    });
    final key = GlobalKey();
    Future<void> capturar(String nombre, Widget child) async {
      await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(1440, 900), disableAnimations: true),
            child: RepaintBoundary(key: key, child: child)),
      )));
      await tester.pump();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('build/login-preview/$nombre.png')
            .writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capturar('login', const LoginPage());
    await capturar(
        'qr-ampliado',
        Scaffold(
            body: Center(
                child: ParteMedicoQrWidget(
                    qr: ParteMedicoQr.parse('00000422'), size: 260))));
  });
}

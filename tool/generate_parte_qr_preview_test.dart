// flutter test tool/generate_parte_qr_preview_test.dart
// Genera únicamente datos ficticios para revisar ubicación y lectura.
import 'dart:io';

import 'package:app_horas/features/medicos/data/parte_medico_printer.dart';
import 'package:app_horas/features/medicos/domain/parte_medico.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('genera muestras de QR sin conectarse a Supabase', () async {
    final parte = ParteMedico.fromJson({
      'id': 42,
      'dni': 12345678,
      'fecha': '2026-10-23',
      'tipo': 'CONSULTORIO',
      'empleado_apellido': 'DEMOSTRACION',
      'empleado_nombre': 'Persona ficticia',
      'empleado_legajo': 123,
      'codigo_qr': '00000422',
    });
    await Directory('build/qr-preview').create(recursive: true);
    await File('build/qr-preview/parte-con-qr.pdf')
        .writeAsBytes(await ParteMedicoPrinter.generarVistaPrevia(parte));
    await File('build/qr-preview/impresion-con-qr.pdf')
        .writeAsBytes(await ParteMedicoPrinter.generar(parte));
  });
}

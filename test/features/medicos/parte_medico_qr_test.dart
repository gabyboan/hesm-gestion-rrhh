import 'package:app_horas/features/medicos/domain/parte_medico.dart';
import 'package:app_horas/features/medicos/domain/medico_domicilio.dart';
import 'package:app_horas/features/medicos/domain/parte_medico_qr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('QR, código manual y transcripción con espacios identifican lo mismo',
      () {
    const codigo = '00000422';
    for (final entrada in [
      codigo,
      'HESM:PM:1:$codigo',
      'pm-0000-0422',
      'PM-0000\n0422'
    ]) {
      final qr = ParteMedicoQr.parse(entrada);
      expect(qr.codigo, codigo);
      expect(qr.contenido, 'HESM:PM:1:$codigo');
      expect(qr.codigoManual, 'PM-0000-0422');
    }
  });

  test('rechaza versiones ajenas, códigos incompletos y textos de otro origen',
      () {
    for (final entrada in [
      '',
      '123',
      'HESM:PM:2:00000422',
      'https://example.com/00000422',
      'GGGG-EF01-2345-6789'
    ]) {
      expect(() => ParteMedicoQr.parse(entrada), throwsFormatException);
    }
  });

  test('detecta errores de tipeo y conserva los ceros iniciales', () {
    expect(ParteMedicoQr.parse('0000 0422').codigo, '00000422');
    for (final codigo in ['00000423', '00000432', '422', '0000042']) {
      expect(() => ParteMedicoQr.parse(codigo), throwsFormatException);
    }
  });

  test('conserva el código al completar domicilio y tolera partes anteriores',
      () {
    final json = <String, dynamic>{
      'id': 7,
      'dni': 12345678,
      'fecha': '2026-10-23',
      'tipo': 'CONSULTORIO',
      'codigo_qr': '00000422'
    };
    final parte =
        ParteMedico.fromJson(json).conDomicilio(const MedicoDomicilio());
    expect(parte.qr!.contenido, 'HESM:PM:1:00000422');
    json.remove('codigo_qr');
    expect(ParteMedico.fromJson(json).qr, isNull);
  });
}

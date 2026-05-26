import 'package:flutter_test/flutter_test.dart';

import 'package:app_horas/core/utils/date_fmt.dart';

void main() {
  group('DateFmt', () {
    test('formatea ddmm', () {
      expect(DateFmt.ddmm(DateTime(2026, 5, 9)), '09/05');
    });

    test('formatea minutos cortos sin horas', () {
      expect(DateFmt.hhmmCorto(30), "30'");
    });

    test('formatea minutos cortos con horas', () {
      expect(DateFmt.hhmmCorto(90), '1:30');
    });

    test('resume fechas ordenadas', () {
      final resumen = DateFmt.resumenFechasDdmm({
        DateTime(2026, 5, 12): 1,
        DateTime(2026, 5, 3): 1,
      });

      expect(resumen, '03/05 | 12/05');
    });

    test('resume minutos con fecha ordenados', () {
      final resumen = DateFmt.resumenMinutosConFecha({
        DateTime(2026, 5, 12): 60,
        DateTime(2026, 5, 3): 30,
      });

      expect(resumen, "30' 03/05 | 1:00 12/05");
    });
  });
}

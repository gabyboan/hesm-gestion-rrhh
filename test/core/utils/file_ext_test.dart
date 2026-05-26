import 'package:flutter_test/flutter_test.dart';

import 'package:app_horas/core/utils/file_ext.dart';

void main() {
  group('ensureFileExtension', () {
    test('agrega la extension cuando falta', () {
      expect(ensureFileExtension('informe', 'xlsx'), 'informe.xlsx');
    });

    test('acepta extension con punto', () {
      expect(ensureFileExtension('informe', '.xlsx'), 'informe.xlsx');
    });

    test('no duplica extension existente', () {
      expect(ensureFileExtension('informe.xlsx', 'xlsx'), 'informe.xlsx');
    });

    test('respeta extension existente aunque tenga mayusculas', () {
      expect(ensureFileExtension('informe.XLSX', 'xlsx'), 'informe.XLSX');
    });
  });
}

import 'package:app_horas/core/export/export_informe_xlsx.dart';
import 'package:app_horas/features/horas/application/informe_providers.dart';
import 'package:app_horas/features/horas/domain/persona.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  const personaParticular = Persona(
    apellido: 'Alvarez',
    nombre: 'Ana',
    dni: 12345678,
    carreraId: 1,
    carrera: 'Titulares',
  );
  const personaSoloOficial = Persona(
    apellido: 'Benitez',
    nombre: 'Bruno',
    dni: 23456789,
    carreraId: 1,
    carrera: 'Titulares',
  );

  test('crea una sola hoja y no agrega al detalle particular filas sin detalle',
      () {
    final workbook = buildInformeExcel(
      periodo: DateTime(2026, 10),
      filtros: {InformeFiltro.soloConUso},
      rows: [
        InformeRow(
          persona: personaParticular,
          particularesPorDia: {DateTime(2026, 10, 5): 60},
          enfermedadPorDia: const {},
          oficialesPorDia: const {},
        ),
        InformeRow(
          persona: personaSoloOficial,
          particularesPorDia: {},
          enfermedadPorDia: {},
          oficialesPorDia: {DateTime(2026, 10, 6): 30},
        ),
      ],
    );

    final decoded = Excel.decodeBytes(workbook.encode()!);
    expect(decoded.sheets.keys, ['Titulares y Sup Ext']);
    expect(
        decoded.sheets['Titulares y Sup Ext']!
            .cell(CellIndex.indexByString('B4'))
            .value
            .toString(),
        'Alvarez, Ana');
    expect(
        decoded.sheets['Titulares y Sup Ext']!
            .cell(CellIndex.indexByString('B5'))
            .value,
        isNull);
  });
}

import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';

import '../../features/horas/application/informe_providers.dart';

String _ddmm(DateTime d) =>
    "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}";

String _hhmm(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return "${m}'";
  return "$h:${m.toString().padLeft(2, '0')}";
}

String _resumenEnfermedad(Map<DateTime, int> porDia) {
  if (porDia.isEmpty) return '';
  final dias = porDia.keys.toList()..sort();
  return dias.map(_ddmm).join(" | ");
}

String _resumenMinutosConFecha(Map<DateTime, int> porDia) {
  if (porDia.isEmpty) return '';
  final dias = porDia.keys.toList()..sort();
  return dias.map((d) => "${_hhmm(porDia[d]!)} ${_ddmm(d)}").join(" | ");
}

Future<void> exportInformeXlsx({
  required DateTime periodo,
  required List<InformeRow> rows,
}) async {
  final excel = Excel.createExcel();

  // ✅ borrar la hoja default (Sheet1)
  final defaultName = excel.sheets.keys.first;
  excel.delete(defaultName);

  const sheetName = 'Titulares y Sup Ext';
  final sheet = excel[sheetName];

  // ===== Título
  final titulo = DateFormat('MMMM yyyy', 'es').format(periodo).toLowerCase();
  final titleCell = sheet.cell(CellIndex.indexByString('B1'));
  titleCell.value = TextCellValue(titulo);
  titleCell.cellStyle = CellStyle(
    bold: true,
    fontSize: 16,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );

  // ===== Encabezados (fila 3)
  final headerStyle = CellStyle(
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );

  sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue('Enfermedad');
  sheet.cell(CellIndex.indexByString('B3')).value =
      TextCellValue('Apellido, Nombre');
  sheet.cell(CellIndex.indexByString('C3')).value =
      TextCellValue('Particulares');

  sheet.cell(CellIndex.indexByString('A3')).cellStyle = headerStyle;
  sheet.cell(CellIndex.indexByString('B3')).cellStyle = headerStyle;
  sheet.cell(CellIndex.indexByString('C3')).cellStyle = headerStyle;

  // ===== Datos particulares/enfermedad (desde fila 4)
  var rExcel = 4;
  for (final r in rows) {
    final p = r.persona;

    sheet.cell(CellIndex.indexByString('A$rExcel')).value =
        TextCellValue(_resumenEnfermedad(r.enfermedadPorDia));
    sheet.cell(CellIndex.indexByString('B$rExcel')).value =
        TextCellValue("${p.apellido}, ${p.nombre}");
    sheet.cell(CellIndex.indexByString('C$rExcel')).value =
        TextCellValue(_resumenMinutosConFecha(r.particularesPorDia));
    rExcel++;
  }

  // ===== Sección oficiales al final
  rExcel += 2;

  // Separador / título sección
  sheet.merge(
    CellIndex.indexByString('A$rExcel'),
    CellIndex.indexByString('C$rExcel'),
  );
  final ofTitle = sheet.cell(CellIndex.indexByString('A$rExcel'));
  ofTitle.value = TextCellValue('HORAS OFICIALES');
  ofTitle.cellStyle = CellStyle(
    bold: true,
    fontSize: 14,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );

  rExcel++;

  // Encabezados oficiales
  sheet.cell(CellIndex.indexByString('A$rExcel')).value =
      TextCellValue('Oficiales');
  sheet.cell(CellIndex.indexByString('B$rExcel')).value =
      TextCellValue('Apellido, Nombre');
  sheet.cell(CellIndex.indexByString('C$rExcel')).value =
      TextCellValue('Detalle');

  sheet.cell(CellIndex.indexByString('A$rExcel')).cellStyle = headerStyle;
  sheet.cell(CellIndex.indexByString('B$rExcel')).cellStyle = headerStyle;
  sheet.cell(CellIndex.indexByString('C$rExcel')).cellStyle = headerStyle;

  rExcel++;

  // Filas oficiales: solo quienes tengan algo (si querés TODOS, decímelo)
  for (final r in rows) {
    if (r.oficialesPorDia.isEmpty) continue;

    final p = r.persona;

    sheet.cell(CellIndex.indexByString('A$rExcel')).value = TextCellValue('SI');
    sheet.cell(CellIndex.indexByString('B$rExcel')).value =
        TextCellValue("${p.apellido}, ${p.nombre}");
    sheet.cell(CellIndex.indexByString('C$rExcel')).value =
        TextCellValue(_resumenMinutosConFecha(r.oficialesPorDia));

    rExcel++;
  }

  // Guardar
  final outBytes = excel.encode();
  if (outBytes == null) throw Exception('No se pudo generar XLSX');

  final suggestedName =
      "${DateFormat('MM', 'es').format(periodo)}-${DateFormat('MMMM yyyy', 'es').format(periodo)}.xlsx";

  final saveLocation = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Excel', extensions: ['xlsx']),
    ],
  );
  if (saveLocation == null) return;

  final file = XFile.fromData(
    Uint8List.fromList(outBytes),
    name: suggestedName,
    mimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );

  await file.saveTo(saveLocation.path);
}

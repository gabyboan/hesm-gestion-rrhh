import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';

import '../../features/horas/application/informe_providers.dart';
import '../utils/date_fmt.dart';

/// Exporta el informe mensual a XLSX.
///
/// Devuelve:
/// - true: si el archivo fue guardado correctamente.
/// - false: si el usuario canceló la ventana de guardado.
/// - throw: si hubo un error real generando o guardando el archivo.
Future<bool> exportInformeXlsx({
  required DateTime periodo,
  required List<InformeRow> rows,
}) async {
  final excel = Excel.createExcel();

  // Borrar la hoja default.
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

  // ===== Encabezados
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

  // ===== Datos particulares / enfermedad
  var rExcel = 4;

  for (final r in rows) {
    final p = r.persona;

    sheet.cell(CellIndex.indexByString('A$rExcel')).value =
        TextCellValue(DateFmt.resumenFechasDdmm(r.enfermedadPorDia));

    sheet.cell(CellIndex.indexByString('B$rExcel')).value =
        TextCellValue("${p.apellido}, ${p.nombre}");

    sheet.cell(CellIndex.indexByString('C$rExcel')).value =
        TextCellValue(DateFmt.resumenMinutosConFecha(r.particularesPorDia));

    rExcel++;
  }

  // ===== Sección oficiales
  rExcel += 2;

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

  for (final r in rows) {
    if (r.oficialesPorDia.isEmpty) continue;

    final p = r.persona;

    sheet.cell(CellIndex.indexByString('A$rExcel')).value = TextCellValue('SI');

    sheet.cell(CellIndex.indexByString('B$rExcel')).value =
        TextCellValue("${p.apellido}, ${p.nombre}");

    sheet.cell(CellIndex.indexByString('C$rExcel')).value =
        TextCellValue(DateFmt.resumenMinutosConFecha(r.oficialesPorDia));

    rExcel++;
  }

  // ===== Generar bytes
  final outBytes = excel.encode();

  if (outBytes == null) {
    throw Exception('No se pudo generar XLSX');
  }

  final suggestedName =
      "${DateFormat('MM', 'es').format(periodo)}-${DateFormat('MMMM yyyy', 'es').format(periodo)}.xlsx";

  final saveLocation = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Excel', extensions: ['xlsx']),
    ],
  );

  // Usuario canceló.
  if (saveLocation == null) {
    return false;
  }

  final file = XFile.fromData(
    Uint8List.fromList(outBytes),
    name: suggestedName,
    mimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );

  await file.saveTo(saveLocation.path);

  return true;
}

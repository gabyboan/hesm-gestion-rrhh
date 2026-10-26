import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';

import '../../features/horas/application/informe_providers.dart';
import '../utils/date_fmt.dart';
import '../utils/file_ext.dart';

const _xlsxMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

const _carrerasParticularesEnfermedad = {1, 3};

/// Exporta el informe mensual a XLSX.
///
/// Devuelve:
/// - true: si el archivo fue guardado correctamente.
/// - false: si el usuario canceló la ventana de guardado.
/// - throw: si hubo un error real generando o guardando el archivo.
Future<bool> exportInformeXlsx({
  required DateTime periodo,
  required List<InformeRow> rows,
  required Set<InformeFiltro> filtros,
}) async {
  final excel = buildInformeExcel(
    periodo: periodo,
    rows: rows,
    filtros: filtros,
  );

  final outBytes = excel.encode();
  if (outBytes == null) {
    throw Exception('No se pudo generar XLSX');
  }

  final suggestedName =
      "${DateFormat('MM', 'es').format(periodo)}-${DateFormat('MMMM yyyy', 'es').format(periodo)}.xlsx";

  final saveLocation = await _chooseSaveLocation(suggestedName);

  if (saveLocation == null) {
    return false;
  }

  final file = XFile.fromData(
    Uint8List.fromList(outBytes),
    name: suggestedName,
    mimeType: _xlsxMimeType,
  );

  final path = ensureFileExtension(saveLocation.path, 'xlsx');
  try {
    await file.saveTo(path);
  } on FileSystemException catch (error) {
    if (!Platform.isWindows || !{32, 33}.contains(error.osError?.errorCode)) {
      rethrow;
    }

    final alternateName = _suggestCopyName(suggestedName);
    final alternateLocation = await _chooseSaveLocation(alternateName);
    if (alternateLocation == null) {
      return false;
    }

    await file.saveTo(ensureFileExtension(alternateLocation.path, 'xlsx'));
  }

  return true;
}

Future<FileSaveLocation?> _chooseSaveLocation(String suggestedName) {
  return getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Excel', extensions: ['xlsx']),
    ],
  );
}

String _suggestCopyName(String fileName) {
  final baseName = fileName.toLowerCase().endsWith('.xlsx')
      ? fileName.substring(0, fileName.length - '.xlsx'.length)
      : fileName;
  final time = DateFormat('HHmmss').format(DateTime.now());
  return '$baseName - copia $time.xlsx';
}

Excel buildInformeExcel({
  required DateTime periodo,
  required List<InformeRow> rows,
  required Set<InformeFiltro> filtros,
}) {
  final excel = Excel.createExcel();
  const sheetName = 'Titulares y Sup Ext';
  final sheet = excel[sheetName];
  final defaultName = excel.sheets.keys.firstWhere((name) => name != sheetName);
  excel.delete(defaultName);
  excel.setDefaultSheet(sheetName);

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

  final filasParticularesEnfermedad = rows.where((row) {
    final carreraIncluida =
        _carrerasParticularesEnfermedad.contains(row.persona.carreraId);
    final tieneDetalle = row.tieneParticulares || row.tieneEnfermedad;
    return carreraIncluida && (filtros.isEmpty || tieneDetalle);
  });

  for (final r in filasParticularesEnfermedad) {
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

  final rowsOficialesConUso = rows.where((row) {
    return row.oficialesPorDia.isNotEmpty;
  });

  for (final r in rowsOficialesConUso) {
    final p = r.persona;

    sheet.cell(CellIndex.indexByString('A$rExcel')).value = TextCellValue('SI');

    sheet.cell(CellIndex.indexByString('B$rExcel')).value =
        TextCellValue("${p.apellido}, ${p.nombre}");

    sheet.cell(CellIndex.indexByString('C$rExcel')).value =
        TextCellValue(DateFmt.resumenMinutosConFecha(r.oficialesPorDia));

    rExcel++;
  }

  return excel;
}

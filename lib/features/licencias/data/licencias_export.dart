import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';

import '../../../core/utils/date_fmt.dart';
import '../../../core/utils/file_ext.dart';
import '../domain/licencia.dart';

Excel buildLicenciasExcel(List<LicenciaRegistro> rows) {
  final book = Excel.createExcel();
  final sheet = book['Licencias'];
  book.delete('Sheet1');
  sheet.appendRow([
    for (final label in [
      'DNI',
      'Apellido y Nombre',
      'Licencia',
      'Desde',
      'Hasta',
      'Cant',
      'Carrera',
      'Situación de revista',
      'Función',
      'Observación',
      'Estado',
      'Referencia de origen',
      'Código',
      'DNI del familiar',
      'Número de orden',
      'Cantidad en ficha',
      'Unidad de días',
      'Días calendario del período',
      'Año del cupo',
    ])
      TextCellValue(label),
  ]);
  for (final row in rows) {
    sheet.appendRow([
      IntCellValue(row.dni),
      TextCellValue(row.nombre),
      TextCellValue(row.tipo),
      TextCellValue(DateFmt.ddmmyyyy(row.desde)),
      TextCellValue(DateFmt.ddmmyyyy(row.hasta)),
      IntCellValue(row.dias),
      TextCellValue(row.carrera),
      TextCellValue(row.situacion),
      TextCellValue(row.funcion),
      TextCellValue(row.observacion ?? ''),
      TextCellValue(row.estado),
      TextCellValue(row.referenciaOrigen ?? ''),
      TextCellValue(row.codigo ?? ''),
      row.dniFamiliar == null ? null : IntCellValue(row.dniFamiliar!),
      row.numeroOrden == null ? null : IntCellValue(row.numeroOrden!),
      TextCellValue(row.cantidadFicha ?? ''),
      TextCellValue(row.esEstudio
          ? 'Hábiles'
          : row.cantidadDiasFicha != null
              ? 'Según ficha'
              : 'Calendario'),
      IntCellValue(row.diasCalendario ?? diasLicencia(row.desde, row.hasta)),
      row.anioCupo == null ? null : IntCellValue(row.anioCupo!),
    ]);
  }
  book.setDefaultSheet('Licencias');
  return book;
}

Future<bool> exportLicenciasExcel(List<LicenciaRegistro> rows, int anio) async {
  final location = await getSaveLocation(
    suggestedName: 'Licencias-$anio.xlsx',
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Excel', extensions: ['xlsx'])
    ],
  );
  if (location == null) return false;
  final bytes = buildLicenciasExcel(rows).encode();
  if (bytes == null) throw StateError('No se pudo generar el informe.');
  await XFile.fromData(Uint8List.fromList(bytes), name: 'Licencias-$anio.xlsx')
      .saveTo(ensureFileExtension(location.path, 'xlsx'));
  return true;
}

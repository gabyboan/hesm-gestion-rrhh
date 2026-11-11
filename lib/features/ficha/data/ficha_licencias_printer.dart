import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/date_fmt.dart';
import '../../licencias/domain/licencia.dart';
import '../domain/ficha_persona.dart';

class FichaRenglon {
  const FichaRenglon(this.registroId, this.columnas,
      {this.continuacion = false, this.documentacionPendiente = false});
  final int registroId;
  final List<String> columnas;
  final bool continuacion;
  final bool documentacionPendiente;
}

class FichaLicenciasPrinter {
  const FichaLicenciasPrinter._();
  static final formato = PdfPageFormat.a4.landscape;
  static const filasPrimeraPagina = 19;
  static const filasContinuacion = 21;
  static const _columnas = <String, int>{
    'ANUAL': 1,
    'ENFERMEDAD': 2,
    'PROFILACTICA': 3,
    'FRANCO': 4,
    'MATERNIDAD': 5,
    'ESTUDIO': 6,
    'ART8': 7,
    'FALTA_CA': 8,
    'FALTA_SA': 9,
  };
  static const _pesos = <double>[
    42,
    82,
    52,
    52,
    52,
    52,
    52,
    41,
    28,
    28,
    27,
    27,
    27,
    27,
    27,
    27,
    75,
    42
  ];

  static List<List<FichaRenglon>> paginar(
      {required FichaPersona persona,
      required List<LicenciaRegistro> registros,
      required int? anio}) {
    if (anio != null && anio < 2026) {
      throw ArgumentError('Las fichas comienzan en 2026.');
    }
    if (registros.any((r) => r.dni != persona.dni)) {
      throw ArgumentError(
          'Las licencias deben corresponder a la persona de la ficha.');
    }
    final inicio = DateTime(anio ?? 2026, 1, 1);
    final fin = DateTime(anio ?? 9999, 12, 31);
    final ordenados = registros
        .where((r) =>
            !r.anulado &&
            (anio == null
                ? !r.desde.isBefore(inicio)
                : !r.hasta.isBefore(inicio)) &&
            !r.desde.isAfter(fin))
        .toList()
      ..sort((a, b) {
        final fecha = a.desde.compareTo(b.desde);
        return fecha == 0 ? a.id.compareTo(b.id) : fecha;
      });
    final renglones = <FichaRenglon>[];
    for (final r in ordenados) {
      final unSoloDia = r.desde.year == r.hasta.year &&
          r.desde.month == r.hasta.month &&
          r.desde.day == r.hasta.day;
      final columna = _columnas[r.columnaFicha];
      final observacion = [
        if (columna == null) '${r.tipo}: ${r.cantidadFicha ?? r.dias} días',
        if (r.dniFamiliar != null) 'DNI: ${r.dniFamiliar}',
        if (r.observacion?.trim().isNotEmpty == true) r.observacion!.trim(),
        if (r.documentacionPendiente) 'Documentación pendiente',
      ].join(' / ');
      final fragmentos = _fragmentarObservacion(observacion);
      for (var i = 0; i < fragmentos.length; i++) {
        final cells = List.filled(18, '');
        cells[0] = '${r.codigo ?? ''}${i == 0 ? '' : ' (cont.)'}';
        cells[16] = fragmentos[i];
        if (i == 0) {
          if (columna != null) {
            cells[columna] = r.cantidadFicha?.isNotEmpty == true
                ? r.cantidadFicha!
                : '${r.dias}';
          }
          cells[10] = '${r.desde.day}';
          cells[11] = '${r.desde.month}';
          cells[12] = '${r.desde.year}';
          cells[13] = unSoloDia ? '/' : '${r.hasta.day}';
          cells[14] = unSoloDia ? '/' : '${r.hasta.month}';
          cells[15] = unSoloDia ? '/' : '${r.hasta.year}';
          cells[17] = r.numeroOrden?.toString() ?? '';
        }
        renglones.add(FichaRenglon(r.id, cells,
            continuacion: i > 0,
            documentacionPendiente: r.documentacionPendiente));
      }
    }
    final paginas = <List<FichaRenglon>>[];
    var offset = 0;
    do {
      final capacidad =
          paginas.isEmpty ? filasPrimeraPagina : filasContinuacion;
      final finPagina = math.min(offset + capacidad, renglones.length);
      paginas.add(renglones.sublist(offset, finPagina));
      offset = finPagina;
    } while (offset < renglones.length);
    return paginas;
  }

  // Dos líneas monoespaciadas por renglón. Los textos largos continúan en otro
  // renglón y, si hace falta, en otra hoja: no se recortan observaciones.
  static List<String> _fragmentarObservacion(String text) {
    final caracteres = text.replaceAll(RegExp(r'\s+'), ' ').runes.toList();
    if (caracteres.isEmpty) return [''];
    final resultado = <String>[];
    for (var start = 0; start < caracteres.length; start += 40) {
      final end = math.min(start + 40, caracteres.length);
      final corte = math.min(start + 20, end);
      resultado.add(String.fromCharCodes(caracteres.sublist(start, corte)) +
          (corte < end
              ? '\n${String.fromCharCodes(caracteres.sublist(corte, end))}'
              : ''));
    }
    return resultado;
  }

  static Future<Uint8List> generar(
      {required FichaPersona persona,
      required List<LicenciaRegistro> registros,
      required int? anio}) async {
    final paginas = paginar(persona: persona, registros: registros, anio: anio);
    final periodo = anio == null ? 'Desde 2026' : 'Año $anio';
    final doc = pw.Document(
        title: 'Ficha de registro de licencias - $periodo',
        author: 'División Recursos Humanos',
        compress: false);
    final normal = pw.Font.helvetica();
    final negrita = pw.Font.helveticaBold();
    final mono = pw.Font.courier();
    for (var pagina = 0; pagina < paginas.length; pagina++) {
      final primera = pagina == 0;
      doc.addPage(pw.Page(
          pageFormat: formato,
          margin: pw.EdgeInsets.zero,
          build: (_) {
            const left = 28.0;
            final ancho = formato.width - left * 2;
            final unidad = ancho / _pesos.reduce((a, b) => a + b);
            final anchos = _pesos.map((p) => p * unidad).toList();
            final xs = <double>[left];
            for (final w in anchos) {
              xs.add(xs.last + w);
            }
            final elementos = <pw.Widget>[];
            void texto(double x, double y, double w, double h, String value,
                {double size = 8,
                bool bold = false,
                bool borde = false,
                bool courier = false,
                PdfColor color = PdfColors.black,
                PdfColor? fondo,
                bool centro = false}) {
              elementos.add(pw.Positioned(
                  left: x,
                  top: y,
                  right: formato.width - x - w,
                  bottom: formato.height - y - h,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 2, vertical: 1),
                    alignment:
                        centro ? pw.Alignment.center : pw.Alignment.centerLeft,
                    decoration: borde
                        ? pw.BoxDecoration(
                            color: fondo, border: pw.Border.all(width: 0.35))
                        : null,
                    child: pw.Text(value,
                        textAlign:
                            centro ? pw.TextAlign.center : pw.TextAlign.left,
                        style: pw.TextStyle(
                            font: courier
                                ? mono
                                : bold
                                    ? negrita
                                    : normal,
                            fontSize: size,
                            color: color)),
                  )));
            }

            texto(left, 28, ancho * 0.65, 18, 'FICHA DE REGISTRO DE LICENCIAS',
                size: 13, bold: true);
            texto(left + ancho * 0.73, 28, ancho * 0.27, 18,
                'División Recursos Humanos',
                size: 9, bold: true);
            texto(left, 53, ancho * 0.53, 20,
                'Apellido y Nombres: ${persona.nombre}',
                bold: true);
            texto(left + ancho * 0.53, 53, ancho * 0.20, 20,
                'Legajo Nº: ${persona.legajo ?? ''}',
                bold: true);
            texto(left + ancho * 0.73, 53, ancho * 0.27, 20,
                'Documento Nº: ${persona.dni}',
                bold: true);
            if (primera) {
              texto(left, 74, ancho * 0.53, 20,
                  'Domicilio: ${persona.domicilio}');
              texto(left + ancho * 0.53, 74, ancho * 0.23, 20,
                  'Fecha de Ingreso: ${persona.fechaIngreso == null ? '' : DateFmt.ddmmyyyy(persona.fechaIngreso!)}');
              texto(left + ancho * 0.76, 74, ancho * 0.24, 20,
                  'Fecha de Nac.: ${persona.fechaNacimiento == null ? '' : DateFmt.ddmmyyyy(persona.fechaNacimiento!)}');
              texto(
                  left, 94, ancho * 0.34, 16, 'Teléfono: ${persona.telefono}');
              texto(
                  left + ancho * 0.34,
                  94,
                  ancho * 0.66,
                  16,
                  'Datos adicionales: ${[
                    persona.carrera,
                    persona.situacion,
                    persona.funcion
                  ].where((s) => s.isNotEmpty).join(' / ')}',
                  size: 7);
            }
            final top = primera ? 112.0 : 84.0;
            const altoCabecera = 36.0;
            const labels = [
              'Cod.',
              'Lic. Anual',
              'Día x\nEnferm.',
              'Lic.\nProfiláctica',
              'Días\nFranco',
              'Lic. x\nMatern.',
              'Días x\nEstudio',
              'Art. 8'
            ];
            for (var c = 0; c < 8; c++) {
              texto(xs[c], top, anchos[c], altoCabecera, labels[c],
                  size: 8, bold: true, borde: true, centro: true);
            }
            for (final grupo in [
              (8, 2, 'Faltas'),
              (10, 3, 'Desde'),
              (13, 3, 'Hasta')
            ]) {
              texto(xs[grupo.$1], top, xs[grupo.$1 + grupo.$2] - xs[grupo.$1],
                  18, grupo.$3,
                  bold: true, borde: true, centro: true);
              final sub =
                  grupo.$1 == 8 ? ['C/A', 'S/A'] : ['Día', 'Mes', 'Año'];
              for (var c = 0; c < grupo.$2; c++) {
                final index = grupo.$1 + c;
                texto(xs[index], top + 18, anchos[index], 18, sub[c],
                    size: 7, bold: true, borde: true, centro: true);
              }
            }
            texto(
                xs[16], top, anchos[16], altoCabecera, 'Observ.\n(DNI Fliar.)',
                size: 8, bold: true, borde: true, centro: true);
            texto(xs[17], top, anchos[17], altoCabecera, 'Nº de\nOrden',
                size: 8, bold: true, borde: true, centro: true);
            var y = top + altoCabecera;
            if (primera) {
              texto(left, y, ancho, 18,
                  'OBSERVACIÓN: $periodo. Cantidades del período completo. Las observaciones extensas continúan en renglones siguientes.',
                  size: 7, borde: true);
              y += 18;
            }
            final capacidad = primera ? filasPrimeraPagina : filasContinuacion;
            for (var fila = 0; fila < capacidad; fila++) {
              final pendiente = fila < paginas[pagina].length &&
                  paginas[pagina][fila].documentacionPendiente;
              final datos = fila < paginas[pagina].length
                  ? paginas[pagina][fila].columnas
                  : List.filled(18, '');
              for (var c = 0; c < 18; c++) {
                texto(xs[c], y + fila * 21, anchos[c], 21, datos[c],
                    size: c == 16 ? 6 : 7,
                    courier: c == 16,
                    color: pendiente ? PdfColors.grey600 : PdfColors.black,
                    fondo: pendiente ? PdfColors.grey100 : null,
                    borde: true,
                    centro: c != 16);
              }
            }
            texto(left, 577, ancho, 12,
                '$periodo · Página ${pagina + 1} de ${paginas.length}${registros.any((r) => r.documentacionPendiente) ? ' · Gris: documentación pendiente' : ''}',
                size: 8, centro: true);
            return pw.SizedBox(
                width: formato.width,
                height: formato.height,
                child: pw.Stack(children: elementos));
          }));
    }
    return doc.save();
  }
}

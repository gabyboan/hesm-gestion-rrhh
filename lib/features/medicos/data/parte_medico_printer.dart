import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/date_fmt.dart';
import '../domain/parte_medico.dart';

class ParteMedicoPrinter {
  const ParteMedicoPrinter._();

  static Future<void> imprimir(ParteMedico parte) async {
    await Printing.layoutPdf(
      name:
          'parte-medico-${parte.empleadoLegajo}-${DateFmt.yyyymmdd(parte.fecha)}',
      format: PdfPageFormat.a4,
      onLayout: (_) => generar(parte),
    );
  }

  static Future<Uint8List> generar(ParteMedico parte) async {
    final doc = pw.Document();
    final familiar = parte.tipo.requiereFamiliar;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Stack(
          children: [
            _text(
              DateFmt.ddmmyyyy(parte.fecha),
              left: 455,
              top: 76,
              width: 100,
            ),
            if (_fits(parte.empleadoCompleto, 215))
              _text(
                parte.empleadoCompleto,
                left: 343,
                top: 140,
                width: 215,
                maxFontSize: 9.5,
              ),
            _text(
              parte.empleadoLegajo.toString(),
              left: 111,
              top: 157,
              width: 75,
            ),
            if (familiar)
              _text(
                parte.familiarApellidoNombre ?? '',
                left: 469,
                top: 157,
                width: 92,
                maxFontSize: 7.5,
              ),
            if (familiar)
              _text(
                'Edad: ${parte.familiarEdad} - ${parte.familiarParentesco}',
                left: 66,
                top: 173,
                width: 125,
                maxFontSize: 8,
              ),
            if (parte.tipo.tachaConsultorio) ...[
              _strike(left: 137, top: 254, width: 408),
              _strike(left: 65, top: 269, width: 96),
            ],
          ],
        ),
      ),
    );

    return doc.save();
  }

  static pw.Widget _text(
    String value, {
    required double left,
    required double top,
    required double width,
    double maxFontSize = 10,
  }) {
    final fontSize = _fitFontSize(value, width, maxFontSize);
    return pw.Positioned(
      left: left,
      top: top,
      child: pw.SizedBox(
        width: width,
        child: pw.Text(
          value,
          maxLines: 1,
          style: pw.TextStyle(fontSize: fontSize),
        ),
      ),
    );
  }

  static pw.Widget _strike({
    required double left,
    required double top,
    required double width,
  }) {
    return pw.Positioned(
      left: left,
      top: top,
      child: pw.Container(width: width, height: 1.4, color: PdfColors.black),
    );
  }

  static double _fitFontSize(String value, double width, double maximum) {
    if (value.isEmpty) return maximum;
    final estimated = width / (value.length * 0.55);
    return estimated.clamp(6.0, maximum).toDouble();
  }

  static bool _fits(String value, double width) {
    return value.length * 0.55 * 6 <= width;
  }
}

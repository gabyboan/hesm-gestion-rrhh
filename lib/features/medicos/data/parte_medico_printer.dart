import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/date_fmt.dart';
import '../domain/ajuste_impresion_medica.dart';
import '../domain/medico_domicilio.dart';
import '../domain/parte_medico.dart';
import 'ajuste_impresion_medica_repository.dart';

class ParteMedicoPrinter {
  const ParteMedicoPrinter._();

  static const _formularioAsset = 'assets/parte_medico_digitalizado.jpg';
  // Calibración sobre la hoja preimpresa: subir un renglón (15 puntos),
  // luego bajar 0,2 mm y desplazar 0,5 mm a la derecha.
  static const _ajusteVerticalImpresion = 15.0 - 0.2 * PdfPageFormat.mm;
  static const _ajusteHorizontalImpresion = 0.5 * PdfPageFormat.mm;
  static const _tamanoFuente = 11.5;

  static Future<bool> imprimir(
    ParteMedico parte, {
    AjusteImpresionMedica? ajuste,
  }) async {
    final calibracion =
        ajuste ?? await const AjusteImpresionMedicaRepository().cargar();
    return Printing.layoutPdf(
      name:
          'parte-medico-${parte.empleadoLegajo ?? parte.dni}-${DateFmt.yyyymmdd(parte.fecha)}',
      format: PdfPageFormat.a4,
      onLayout: (_) => generar(parte, ajuste: calibracion),
    );
  }

  static Future<bool> imprimirTodos(
    List<ParteMedico> partes, {
    AjusteImpresionMedica? ajuste,
  }) async {
    final calibracion =
        ajuste ?? await const AjusteImpresionMedicaRepository().cargar();
    final bytes = await generarTodos(partes, ajuste: calibracion);
    return Printing.layoutPdf(
      name: 'partes-medicos-${partes.length}',
      format: PdfPageFormat.a4,
      onLayout: (_) async => bytes,
    );
  }

  static Future<Uint8List> generarTodos(
    List<ParteMedico> partes, {
    AjusteImpresionMedica ajuste = const AjusteImpresionMedica(),
  }) async {
    if (partes.isEmpty) {
      throw ArgumentError('Agregá al menos un parte para imprimir.');
    }
    if (!ajuste.esValido) {
      throw ArgumentError('El ajuste debe estar entre -10 y 10 mm.');
    }
    return _generar(partes, ajuste: ajuste);
  }

  static Future<Uint8List> generar(
    ParteMedico parte, {
    AjusteImpresionMedica ajuste = const AjusteImpresionMedica(),
  }) async {
    if (!ajuste.esValido) {
      throw ArgumentError('El ajuste debe estar entre -10 y 10 mm.');
    }
    return _generar([parte], ajuste: ajuste);
  }

  static Future<Uint8List> generarVistaPrevia(ParteMedico parte) async {
    final asset = await rootBundle.load(_formularioAsset);
    final imageBytes = asset.buffer.asUint8List(
      asset.offsetInBytes,
      asset.lengthInBytes,
    );
    return _generar([parte], formulario: pw.MemoryImage(imageBytes));
  }

  static Future<Uint8List> _generar(
    List<ParteMedico> partes, {
    pw.ImageProvider? formulario,
    AjusteImpresionMedica ajuste = const AjusteImpresionMedica(),
  }) async {
    final doc = pw.Document();
    for (final parte in partes) {
      final familiar = parte.tipo.requiereFamiliar;
      final domicilio = parte.domicilio;

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Transform.translate(
            // La vista previa usa el escaneo; el ajuste corresponde a la impresora.
            // En el PDF, el eje Y positivo desplaza el contenido hacia arriba.
            offset: PdfPoint(
              formulario == null
                  ? _ajusteHorizontalImpresion +
                      ajuste.horizontalMm * PdfPageFormat.mm
                  : 0,
              formulario == null
                  ? _ajusteVerticalImpresion -
                      ajuste.verticalMm * PdfPageFormat.mm
                  : 0,
            ),
            child: pw.Stack(
              children: [
                if (formulario != null)
                  pw.Positioned.fill(
                    child: pw.Image(formulario, fit: pw.BoxFit.fill),
                  ),
                _text(
                  'DNI: ${parte.dni}',
                  left: 290,
                  top: 68,
                  width: 90,
                ),
                if (parte.textoSolicitudAdicional.isNotEmpty)
                  _text(
                    parte.textoSolicitudAdicional,
                    left: 258,
                    top: 96,
                    width: 145,
                  ),
                _text(
                  DateFmt.ddmmyyyy(parte.fecha),
                  left: 455,
                  top: 68,
                  width: 100,
                ),
                _text(
                  parte.empleadoCompleto,
                  left: 343,
                  top: 136,
                  width: 215,
                ),
                _text(
                  parte.empleadoLegajo?.toString() ?? 'SUPLENTE',
                  left: 115,
                  top: 150,
                  width: 75,
                ),
                if (familiar)
                  _text(
                    parte.familiarNombreParaImprimir ?? '',
                    left: 475,
                    top: 148,
                    width: 112,
                  ),
                if (familiar)
                  _text(
                    [
                      if (parte.familiarEdadMeses != null)
                        '${parte.familiarEdadMeses} ${parte.familiarEdadMeses == 1 ? 'mes' : 'meses'}'
                      else if (parte.familiarEdad != null)
                        '${parte.familiarEdad} ${parte.familiarEdad == 1 ? 'año' : 'años'}',
                      if (parte.familiarParentesco?.isNotEmpty == true)
                        parte.familiarParentesco!,
                    ].join(' - '),
                    left: 66,
                    top: 164,
                    width: 125,
                  ),
                if (familiar && parte.familiarDni != null)
                  _text(
                    parte.familiarDni.toString(),
                    left: 285,
                    top: 164,
                    width: 135,
                  ),
                if (parte.aclaracionFechaTurno?.isNotEmpty == true)
                  _aclaracion(parte.aclaracionFechaTurno!),
                if (parte.tipo != TipoParteMedico.consultorio &&
                    domicilio != null &&
                    !domicilio.estaVacio) ...[
                  _text(
                    domicilio.calle ?? '',
                    left: 103,
                    top: 204,
                    width: 177,
                  ),
                  _text(
                    domicilio.numero ?? '',
                    left: 298,
                    top: 204,
                    width: 48,
                  ),
                  _text(
                    domicilio.barrio ?? '',
                    left: 393,
                    top: 204,
                    width: 166,
                  ),
                  _text(
                    domicilio.manzana ?? '',
                    left: 121,
                    top: 219,
                    width: 87,
                  ),
                  _text(
                    domicilio.lote ?? '',
                    left: 244,
                    top: 219,
                    width: 48,
                  ),
                  _text(
                    domicilio.monoblock ?? '',
                    left: 367,
                    top: 219,
                    width: 74,
                  ),
                  _text(
                    domicilio.piso ?? '',
                    left: 478,
                    top: 219,
                    width: 26,
                  ),
                  _text(
                    domicilio.departamento ?? '',
                    left: 540,
                    top: 219,
                    width: 20,
                  ),
                  _text(
                    domicilio.referencias ?? '',
                    left: 198,
                    top: 234,
                    width: 142,
                  ),
                  _text(
                    _otrosDatosDomicilio(domicilio),
                    left: 424,
                    top: 234,
                    width: 136,
                  ),
                ],
                if (parte.tipo.tachaConsultorio) ...[
                  _strike(left: 137, top: 254, width: 408),
                  _strike(left: 65, top: 269, width: 96),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return doc.save();
  }

  static pw.Widget _aclaracion(String value) {
    // El bloque de aclaración puede abarcar más ancho y seguir hacia abajo.
    // Si el texto sigue largo, recortamos sin invadir el resto del formulario.
    const width = 180.0;
    final valueNormalizado = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    final font = pw.Font.helvetica();
    return pw.Positioned(
      left: 388,
      top: 80,
      child: pw.Builder(
        builder: (_) => pw.SizedBox(
          width: width,
          height: 48,
          child: pw.ClipRect(
            child: pw.Align(
              alignment: pw.Alignment.topLeft,
              child: pw.Text(
                valueNormalizado,
                softWrap: true,
                maxLines: 3,
                overflow: pw.TextOverflow.clip,
                style: pw.TextStyle(font: font, fontSize: _tamanoFuente),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static pw.Widget _text(
    String value, {
    required double left,
    required double top,
    required double width,
  }) {
    final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    final font = pw.Font.helvetica();
    return pw.Positioned(
      left: left,
      top: top,
      child: pw.Builder(
        builder: (_) {
          if (text.isEmpty) return pw.SizedBox();
          return pw.SizedBox(
            width: width,
            child: pw.Text(
              text,
              maxLines: 1,
              softWrap: false,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(font: font, fontSize: _tamanoFuente),
            ),
          );
        },
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

  static String _otrosDatosDomicilio(MedicoDomicilio domicilio) {
    final otrosDatos = domicilio.otrosDatos?.trim();
    final numero = domicilio.numero?.trim();
    final values = <String>[
      if (domicilio.torre != null && domicilio.torre!.trim().isNotEmpty)
        'Torre ${domicilio.torre!.trim()}',
      if (domicilio.casa != null &&
          domicilio.casa!.trim().isNotEmpty &&
          domicilio.casa!.trim() != numero)
        domicilio.casa!,
      if (otrosDatos != null && otrosDatos.isNotEmpty && otrosDatos != numero)
        otrosDatos,
      if (domicilio.localidadExterna != null) domicilio.localidadExterna!,
    ];
    return values.join(', ');
  }
}

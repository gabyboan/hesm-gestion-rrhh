import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/parte_medico_qr.dart';

class ParteMedicoQrWidget extends StatelessWidget {
  const ParteMedicoQrWidget({super.key, required this.qr, this.size = 64});
  final ParteMedicoQr qr;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: 'QR del parte ${qr.codigoManual}',
        child: SizedBox.square(
            dimension: size,
            child: CustomPaint(painter: _QrPainter(qr.contenido))),
      );
}

class _QrPainter extends CustomPainter {
  const _QrPainter(this.contenido);
  final String contenido;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final margen = size.shortestSide / 8;
    final barras =
        pw.Barcode.qrCode(errorCorrectLevel: pw.BarcodeQRCorrectionLevel.high)
            .make(contenido,
                width: size.width - margen * 2,
                height: size.height - margen * 2,
                drawText: false);
    final paint = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    for (final barra in barras) {
      if (barra is pw.BarcodeBar && barra.black) {
        canvas.drawRect(
            Rect.fromLTWH(margen + barra.left, margen + barra.top, barra.width,
                barra.height),
            paint);
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) =>
      contenido != oldDelegate.contenido;
}

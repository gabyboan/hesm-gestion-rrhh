import 'dart:convert';
import 'dart:typed_data';

import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';

class FichaPrintingFake extends PrintingPlatform {
  final documentos = <Uint8List>[];
  int impresiones = 0;
  int get paginas => documentos.isEmpty
      ? 0
      : RegExp(r'/Type\s*/Page\b')
          .allMatches(latin1.decode(documentos.last))
          .length;

  @override
  Future<PrintingInfo> info() async => const PrintingInfo(canRaster: true);

  @override
  Stream<PdfRaster> raster(
      Uint8List document, List<int>? pages, double dpi) async* {
    documentos.add(document);
    for (var i = 0; i < paginas; i++) {
      yield _PaginaPrueba();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #layoutPdf) {
      impresiones++;
      return Future.value(true);
    }
    return super.noSuchMethod(invocation);
  }
}

class _PaginaPrueba extends PdfRaster {
  _PaginaPrueba() : super(1, 1, Uint8List.fromList([255, 255, 255, 255]));
  @override
  Future<Uint8List> toPng() async => base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=');
}

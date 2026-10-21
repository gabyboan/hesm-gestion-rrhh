import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../core/utils/error_text.dart';
import '../data/parte_medico_printer.dart';
import '../domain/parte_medico.dart';

Future<void> mostrarVistaPreliminarAmpliada(
  BuildContext context,
  ParteMedico parte,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => ParteMedicoVistaAmpliada(parte: parte),
  );
}

class ParteMedicoVistaAmpliada extends StatefulWidget {
  const ParteMedicoVistaAmpliada({super.key, required this.parte});

  final ParteMedico parte;

  @override
  State<ParteMedicoVistaAmpliada> createState() =>
      _ParteMedicoVistaAmpliadaState();
}

class _ParteMedicoVistaAmpliadaState extends State<ParteMedicoVistaAmpliada> {
  final _transform = TransformationController();
  late Future<Uint8List> _imagen;

  @override
  void initState() {
    super.initState();
    _imagen = _generarImagen();
  }

  Future<Uint8List> _generarImagen() async {
    final pdf = await ParteMedicoPrinter.generarVistaPrevia(widget.parte);
    final pagina = await Printing.raster(pdf, pages: [0], dpi: 180).first;
    return pagina.toPng();
  }

  void _zoom(double factor) {
    final current = _transform.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(0.5, 4.0);
    _transform.value = _transform.value.clone()
      ..scaleByDouble(next / current, next / current, 1, 1);
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: screen.width - 32,
        height: screen.height - 32,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Expanded(
                    child: Text('Vista preliminar ampliada',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700))),
                IconButton(
                  tooltip: 'Cerrar vista ampliada',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ]),
              Text(widget.parte.descripcionRegistro,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              ValueListenableBuilder<Matrix4>(
                valueListenable: _transform,
                builder: (_, matrix, __) => Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Alejar',
                      onPressed: matrix.getMaxScaleOnAxis() <= 0.5
                          ? null
                          : () => _zoom(1 / 1.25),
                      icon: const Icon(Icons.zoom_out),
                    ),
                    Text('${(matrix.getMaxScaleOnAxis() * 100).round()} %'),
                    IconButton(
                      tooltip: 'Acercar',
                      onPressed: matrix.getMaxScaleOnAxis() >= 4
                          ? null
                          : () => _zoom(1.25),
                      icon: const Icon(Icons.zoom_in),
                    ),
                    TextButton(
                      onPressed: () => _transform.value = Matrix4.identity(),
                      child: const Text('Ajustar al ancho'),
                    ),
                    const Text('Arrastrá la hoja para recorrerla.'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<Uint8List>(
                  future: _imagen,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                          child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                              'No se pudo ampliar la vista: ${cleanError(snapshot.error!)}'),
                          TextButton(
                            onPressed: () =>
                                setState(() => _imagen = _generarImagen()),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ));
                    }
                    final bytes = snapshot.data;
                    if (bytes == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return LayoutBuilder(builder: (context, constraints) {
                      return ColoredBox(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: InteractiveViewer(
                          transformationController: _transform,
                          constrained: false,
                          alignment: Alignment.topLeft,
                          minScale: 0.5,
                          maxScale: 4,
                          boundaryMargin: const EdgeInsets.all(24),
                          child: Image.memory(
                            bytes,
                            width: constraints.maxWidth,
                            height: constraints.maxWidth *
                                PdfPageFormat.a4.height /
                                PdfPageFormat.a4.width,
                            fit: BoxFit.fill,
                            filterQuality: FilterQuality.high,
                            gaplessPlayback: true,
                          ),
                        ),
                      );
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/ui/app_snackbar.dart';
import '../../../core/utils/error_text.dart';
import '../../../core/utils/file_ext.dart';
import '../../licencias/domain/licencia.dart';
import '../data/ficha_licencias_printer.dart';
import '../domain/ficha_persona.dart';

Future<void> mostrarFichaImpresion(BuildContext context,
    {required FichaPersona persona,
    required List<LicenciaRegistro> registros,
    required int anio,
    bool acumulada = true}) async {
  await showDialog<void>(
      context: context,
      builder: (_) => _FichaImpresionDialog(
          persona: persona,
          registros: registros,
          anio: anio,
          acumulada: acumulada));
}

class _FichaImpresionDialog extends StatefulWidget {
  const _FichaImpresionDialog(
      {required this.persona,
      required this.registros,
      required this.anio,
      required this.acumulada});
  final FichaPersona persona;
  final List<LicenciaRegistro> registros;
  final int anio;
  final bool acumulada;
  @override
  State<_FichaImpresionDialog> createState() => _FichaImpresionDialogState();
}

class _FichaImpresionDialogState extends State<_FichaImpresionDialog> {
  late bool _acumulada = widget.acumulada;
  late Future<Uint8List> _pdf = _generar();
  Future<Uint8List> _generar() => FichaLicenciasPrinter.generar(
      persona: widget.persona,
      registros: widget.registros,
      anio: _acumulada ? null : widget.anio);
  String get _nombre =>
      'ficha-licencias-${widget.persona.dni}-${_acumulada ? 'desde-2026' : widget.anio}.pdf';
  bool _guardando = false;

  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      final bytes = await _pdf;
      final location = await getSaveLocation(
          suggestedName: _nombre,
          acceptedTypeGroups: const [
            XTypeGroup(label: 'PDF', extensions: ['pdf'])
          ]);
      if (location == null) return;
      await XFile.fromData(bytes, name: _nombre, mimeType: 'application/pdf')
          .saveTo(ensureFileExtension(location.path, 'pdf'));
      if (mounted) AppSnackBar.success(context, 'Ficha guardada');
    } catch (e) {
      if (mounted) AppSnackBar.error(context, cleanError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 1400,
        height: MediaQuery.sizeOf(context).height - 48,
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                    child: Text('Ficha de registro de licencias',
                        style: Theme.of(context).textTheme.titleLarge)),
                DropdownButton<bool>(
                    value: _acumulada,
                    items: [
                      const DropdownMenuItem(
                          value: true, child: Text('Acumulada desde 2026')),
                      DropdownMenuItem(
                          value: false, child: Text('Solo ${widget.anio}')),
                    ],
                    onChanged: _guardando
                        ? null
                        : (value) {
                            if (value == null || value == _acumulada) return;
                            setState(() {
                              _acumulada = value;
                              _pdf = _generar();
                            });
                          }),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Guardar PDF')),
                IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ])),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                  'A4 horizontal · Continúa automáticamente en las hojas siguientes · Sin licencias anuladas')),
          Expanded(
              child: FutureBuilder<Uint8List>(
                  future: _pdf,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text(cleanError(snapshot.error!)));
                    }
                    if (snapshot.connectionState != ConnectionState.done ||
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return PdfPreview(
                        key: ValueKey(_acumulada),
                        build: (_) async => snapshot.data!,
                        pdfFileName: _nombre,
                        initialPageFormat: FichaLicenciasPrinter.formato,
                        maxPageWidth: 2000,
                        canChangePageFormat: false,
                        canChangeOrientation: false,
                        canDebug: false);
                  })),
        ]),
      ));
}

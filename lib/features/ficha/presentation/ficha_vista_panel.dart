import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/utils/error_text.dart';
import '../../licencias/domain/licencia.dart';
import '../application/ficha_providers.dart';
import '../data/ficha_licencias_printer.dart';
import '../domain/ficha_persona.dart';
import 'ficha_impresion_dialog.dart';

class FichaVistaPanel extends ConsumerStatefulWidget {
  const FichaVistaPanel({super.key, required this.persona, required this.anio});
  final FichaPersona persona;
  final int anio;

  @override
  ConsumerState<FichaVistaPanel> createState() => _FichaVistaPanelState();
}

class _FichaVistaPanelState extends ConsumerState<FichaVistaPanel> {
  bool _acumulada = true;

  @override
  Widget build(BuildContext context) {
    final registros =
        ref.watch(fichaLicenciasAcumuladasProvider(widget.persona.dni));
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(
              spacing: 16,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Vista preliminar',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                DropdownButton<bool>(
                  value: _acumulada,
                  items: [
                    const DropdownMenuItem(
                        value: true, child: Text('Acumulada desde 2026')),
                    DropdownMenuItem(
                        value: false, child: Text('Solo ${widget.anio}')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _acumulada = value);
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.zoom_in),
                  label: const Text('Ampliar / imprimir'),
                  onPressed: registros.isLoading ||
                          registros.hasError ||
                          !registros.hasValue
                      ? null
                      : () => mostrarFichaImpresion(context,
                          persona: widget.persona,
                          registros: registros.requireValue,
                          anio: widget.anio,
                          acumulada: _acumulada),
                ),
              ]),
          const SizedBox(height: 4),
          const Text(
              'La planilla continúa en las hojas siguientes. Las cargas se realizan desde Licencias.'),
          const SizedBox(height: 8),
          Expanded(
              child: registros.when(
            skipLoadingOnRefresh: false,
            data: (rows) => _PlanillaPdf(
                key: ValueKey(
                    (widget.persona.dni, _acumulada ? null : widget.anio)),
                persona: widget.persona,
                registros: rows,
                anio: _acumulada ? null : widget.anio),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('No se pudo cargar la planilla: ${cleanError(error)}'),
              TextButton(
                  onPressed: () => ref.invalidate(
                      fichaLicenciasAcumuladasProvider(widget.persona.dni)),
                  child: const Text('Reintentar')),
            ])),
          )),
        ]),
      ),
    );
  }
}

class _PlanillaPdf extends StatefulWidget {
  const _PlanillaPdf(
      {super.key,
      required this.persona,
      required this.registros,
      required this.anio});
  final FichaPersona persona;
  final List<LicenciaRegistro> registros;
  final int? anio;

  @override
  State<_PlanillaPdf> createState() => _PlanillaPdfState();
}

class _PlanillaPdfState extends State<_PlanillaPdf> {
  late Future<Uint8List> _pdf = _generar();
  Future<Uint8List> _generar() => FichaLicenciasPrinter.generar(
      persona: widget.persona, registros: widget.registros, anio: widget.anio);

  @override
  void didUpdateWidget(covariant _PlanillaPdf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.persona != widget.persona ||
        oldWidget.registros != widget.registros ||
        oldWidget.anio != widget.anio) {
      _pdf = _generar();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
        future: _pdf,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                  'No se pudo generar la vista preliminar: ${cleanError(snapshot.error!)}'),
              TextButton(
                  onPressed: () => setState(() => _pdf = _generar()),
                  child: const Text('Reintentar')),
            ]));
          }
          if (snapshot.connectionState != ConnectionState.done ||
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return PdfPreview(
            key: ValueKey(snapshot.data),
            build: (_) async => snapshot.data!,
            initialPageFormat: FichaLicenciasPrinter.formato,
            pageFormats: {'A4 horizontal': FichaLicenciasPrinter.formato},
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            useActions: false,
            allowPrinting: false,
            allowSharing: false,
            maxPageWidth: 1400,
            padding: const EdgeInsets.all(4),
            onError: (_, error) => Center(
                child: Text(
                    'No se pudo mostrar la planilla: ${cleanError(error)}')),
          );
        },
      );
}

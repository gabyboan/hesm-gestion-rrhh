import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../core/utils/date_fmt.dart';
import '../../../core/utils/error_text.dart';
import '../application/medicos_providers.dart';
import '../data/parte_medico_printer.dart';
import '../domain/medico_domicilio.dart';
import '../domain/medico_persona.dart';
import '../domain/parte_medico.dart';
import 'parte_medico_vista_ampliada.dart';
import 'parte_medico_qr_widget.dart';

class ParteMedicoVistaPanel extends ConsumerWidget {
  const ParteMedicoVistaPanel({super.key, this.parte, this.persona});

  final ParteMedico? parte;
  final MedicoPersona? persona;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registro = parte;
    final agente = persona;
    final base = registro ??
        (agente == null
            ? null
            : ParteMedico(
                id: 0,
                dni: agente.dni,
                fecha: DateUtils.dateOnly(DateTime.now()),
                tipo: TipoParteMedico.domicilio,
                empleadoApellido: agente.apellido,
                empleadoNombre: agente.nombre,
                empleadoLegajo: agente.legajo,
                familiarApellidoNombre: null,
                familiarEdad: null,
                familiarParentesco: null,
              ));
    final domicilio = base == null || base.tipo == TipoParteMedico.consultorio
        ? const AsyncData<MedicoDomicilio?>(null)
        : base.domicilio != null
            ? AsyncData<MedicoDomicilio?>(base.domicilio)
            : ref.watch(medicosDomicilioProvider(base.dni));
    final vigente = registro != null &&
        registro.domicilio == null &&
        registro.tipo != TipoParteMedico.consultorio;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Expanded(
                  child: Text('Vista preliminar',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16))),
              if (registro?.qr != null)
                Tooltip(
                  message: 'Ampliar QR del parte',
                  child: InkWell(
                    onTap: () => showDialog<void>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                              title: const Text('QR del parte'),
                              content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ParteMedicoQrWidget(
                                        qr: registro.qr!, size: 260),
                                    const SizedBox(height: 12),
                                    SelectableText(registro.qr!.codigoManual,
                                        style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700)),
                                  ]),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext),
                                    child: const Text('Cerrar'))
                              ],
                            )),
                    child: ParteMedicoQrWidget(qr: registro!.qr!, size: 48),
                  ),
                ),
              IconButton(
                tooltip: 'Ampliar vista preliminar',
                icon: const Icon(Icons.zoom_in),
                onPressed:
                    base == null || domicilio.isLoading || domicilio.hasError
                        ? null
                        : () => mostrarVistaPreliminarAmpliada(
                            context, base.conDomicilio(domicilio.valueOrNull)),
              ),
            ]),
            if (base != null) ...[
              const SizedBox(height: 8),
              Text(base.descripcionRegistro),
              Text('${base.tipo.codigo} · ${DateFmt.ddmmyyyy(base.fecha)}'
                  '${registro == null ? ' · Sin registrar' : ''}'
                  '${base.esArt ? ' · ART' : ''}'),
              if (registro?.qr != null)
                SelectableText(registro!.qr!.codigoManual),
              if (registro == null)
                const Text('El QR se incorpora al registrar el parte.',
                    style: TextStyle(fontSize: 12)),
              if (vigente)
                const Text('Domicilio vigente de la ficha',
                    style: TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: base == null
                  ? const Center(
                      child:
                          Text('Seleccioná una persona o un parte registrado.'))
                  : domicilio.when(
                      data: (value) => PdfPreview(
                        // Conservar la hoja mientras se genera la nueva selección.
                        build: (_) => ParteMedicoPrinter.generarVistaPrevia(
                          base.conDomicilio(value),
                        ),
                        initialPageFormat: PdfPageFormat.a4,
                        pageFormats: const {'A4': PdfPageFormat.a4},
                        canChangePageFormat: false,
                        canChangeOrientation: false,
                        canDebug: false,
                        useActions: false,
                        allowPrinting: false,
                        allowSharing: false,
                        maxPageWidth: 1000,
                        padding: const EdgeInsets.all(4),
                        onError: (_, error) => Center(
                          child: Text(
                              'No se pudo generar la vista preliminar: ${cleanError(error)}'),
                        ),
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Center(
                          child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                              'No se pudo cargar el domicilio: ${cleanError(error)}'),
                          TextButton(
                            onPressed: () => ref
                                .invalidate(medicosDomicilioProvider(base.dni)),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      )),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

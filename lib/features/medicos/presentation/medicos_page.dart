import '../../../core/widgets/app_search_field.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../core/ui/app_snackbar.dart';
import '../../../core/utils/date_fmt.dart';
import '../../../core/utils/error_text.dart';
import '../application/medicos_providers.dart';
import '../application/cola_impresion_provider.dart';
import '../data/parte_medico_printer.dart';
import '../domain/medico_domicilio.dart';
import '../domain/medico_familiar.dart';
import '../domain/medico_persona.dart';
import '../domain/parte_medico.dart';
import '../domain/listado_enfermeria.dart';
import 'ajuste_impresion_medica_dialog.dart';
import 'parte_medico_vista_panel.dart';
import 'parte_medico_vista_ampliada.dart';
import 'cola_impresion_dialog.dart';
import 'control_parte_medico_dialog.dart';

class MedicosPage extends ConsumerStatefulWidget {
  const MedicosPage({super.key});

  @override
  ConsumerState<MedicosPage> createState() => _MedicosPageState();
}

class _MedicosPageState extends ConsumerState<MedicosPage>
    with SingleTickerProviderStateMixin {
  int? _parteSeleccionadoId;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(_cambiarPestana);
  }

  void _cambiarPestana() => setState(() {});

  @override
  void dispose() {
    _tabs.removeListener(_cambiarPestana);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _emitir({
    required BuildContext context,
    required WidgetRef ref,
    required MedicoPersona persona,
  }) async {
    final resultado = await showDialog<_ParteMedicoSubmission>(
      context: context,
      builder: (_) => _ParteMedicoDialog(persona: persona),
    );
    if (resultado == null) return;
    final data = resultado.data;
    int? parteGuardadoId;

    try {
      final id = await ref
          .read(guardarParteMedicoControllerProvider.notifier)
          .crear(data);
      parteGuardadoId = id;
      // Recuperar la fecha, identidad y código definitivos desde el servidor.
      final documento = await ref.read(medicosRepoProvider).documento(id: id);
      final parte = documento.parte.conDomicilio(data.domicilio);
      if (documento.anulado || parte.qr == null) {
        throw StateError('El parte no está disponible para imprimir con QR.');
      }

      if (!context.mounted) return;
      setState(() {
        _parteSeleccionadoId = id;
      });
      ref.read(partesMedicosSearchProvider.notifier).state = '';
      ref.read(partesMedicosFechaElegidaProvider.notifier).state =
          DateUtils.isSameDay(parte.fecha, ref.read(medicosHoyProvider))
              ? null
              : DateUtils.dateOnly(parte.fecha);
      if (resultado.imprimirAhora) {
        _tabs.animateTo(1);
        AppSnackBar.success(context, 'Parte médico registrado');
        try {
          final impreso = await ParteMedicoPrinter.imprimir(parte);
          if (!impreso) {
            ref.read(colaImpresionProvider.notifier).agregar(parte);
            if (context.mounted) {
              AppSnackBar.success(context,
                  'Impresión cancelada. Parte guardado en la bandeja.');
            }
          }
        } catch (e) {
          ref.read(colaImpresionProvider.notifier).agregar(parte);
          if (context.mounted) {
            AppSnackBar.error(context,
                'Parte registrado y agregado a la bandeja. No se pudo imprimir: ${cleanError(e)}');
          }
        }
      } else {
        ref.read(colaImpresionProvider.notifier).agregar(parte);
        AppSnackBar.success(
            context, 'Parte registrado y agregado a la bandeja de impresión');
      }
    } catch (e) {
      if (!context.mounted) return;
      if (parteGuardadoId != null) {
        setState(() => _parteSeleccionadoId = parteGuardadoId);
        ref.read(partesMedicosSearchProvider.notifier).state = '';
        ref.read(partesMedicosFechaElegidaProvider.notifier).state = null;
        _tabs.animateTo(1);
        ref.invalidate(partesMedicosProvider);
        AppSnackBar.error(
            context,
            'El parte N.º $parteGuardadoId quedó registrado. '
            'Reintentá la impresión desde Partes registrados para evitar duplicarlo. '
            '${cleanError(e)}');
      } else {
        AppSnackBar.error(context, cleanError(e));
      }
    }
  }

  Future<void> _anular({
    required BuildContext context,
    required WidgetRef ref,
    required ParteMedico parte,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Anular parte medico'),
        content: Text('Anular el parte de ${parte.empleadoCompleto}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final ok = await ref
          .read(anularParteMedicoControllerProvider.notifier)
          .anular(parte.id);
      if (!context.mounted) return;
      if (ok) {
        ref.read(colaImpresionProvider.notifier).quitar(parte.id);
        AppSnackBar.success(context, 'Parte medico anulado');
      } else {
        AppSnackBar.error(context, 'El parte medico no fue encontrado');
      }
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.error(context, cleanError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final puedeLeerAsync = ref.watch(puedeLeerMedicosProvider);
    final puedeCrear =
        ref.watch(puedeCrearMedicosProvider).valueOrNull ?? false;
    final puedeAdmin =
        ref.watch(puedeAdministrarMedicosProvider).valueOrNull ?? false;
    final selected = ref.watch(selectedMedicoPersonaProvider);
    final busy = ref.watch(guardarParteMedicoControllerProvider).isLoading ||
        ref.watch(anularParteMedicoControllerProvider).isLoading;

    if (puedeLeerAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (puedeLeerAsync.valueOrNull != true) {
      return const _InfoBox(
        text: 'Sin permiso para ver partes medicos. Falta MEDICOS_LECTURA.',
        error: true,
      );
    }

    final verRegistros = _tabs.index == 1;
    final fechaPartes = ref.watch(partesMedicosFechaProvider);
    final hoy = ref.watch(medicosHoyProvider);
    final partes = verRegistros
        ? ref.watch(partesMedicosPorDiaProvider).valueOrNull ?? []
        : <ParteMedico>[];
    final personasDisponibles = verRegistros
        ? <MedicoPersona>[]
        : ref.watch(medicosPersonasProvider).valueOrNull ?? [];
    ParteMedico? parteVisible;
    if (verRegistros) {
      for (final parte in partes) {
        if (parte.id == _parteSeleccionadoId) parteVisible = parte;
      }
      if (parteVisible == null && partes.isNotEmpty) {
        parteVisible = partes.first;
      }
    }
    final personaVisible = !verRegistros
        ? selected ??
            (personasDisponibles.isEmpty ? null : personasDisponibles.first)
        : null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(icon: Icon(Icons.note_add_outlined), text: 'Emitir parte'),
              Tab(icon: Icon(Icons.history), text: 'Partes registrados'),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final search =
                _Toolbar(key: ValueKey(verRegistros), registros: verRegistros);
            final cantidad = ref.watch(colaImpresionProvider).length;
            final bandeja = OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => UncontrolledProviderScope(
                          container: ProviderScope.containerOf(context),
                          child: const ColaImpresionDialog(),
                        ),
                      ),
              icon: const Icon(Icons.print_outlined),
              label: Text('Bandeja de impresión ($cantidad)'),
            );
            final control = OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const ControlParteMedicoDialog(),
                      ),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Control por código'),
            );
            if (constraints.maxWidth < 700) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    search,
                    const SizedBox(height: 8),
                    Wrap(
                        spacing: 8, runSpacing: 8, children: [control, bandeja])
                  ]);
            }
            return Row(children: [
              Expanded(child: search),
              const SizedBox(width: 16),
              control,
              const SizedBox(width: 8),
              bandeja
            ]);
          }),
          if (verRegistros) ...[
            const SizedBox(height: 8),
            _SelectorFechaPartes(
              fecha: fechaPartes,
              hoy: hoy,
              busy: busy,
              onChanged: (fecha) {
                ref.read(partesMedicosFechaElegidaProvider.notifier).state =
                    DateUtils.isSameDay(fecha, hoy) ? null : fecha;
                setState(() {
                  _parteSeleccionadoId = null;
                });
              },
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final personas = _PersonasPanel(
                  selected: personaVisible,
                  canCreate: puedeCrear,
                  busy: busy,
                  onSelected: (persona) {
                    ref.read(selectedMedicoPersonaProvider.notifier).state =
                        persona;
                  },
                  onEmitir: (persona) => _emitir(
                    context: context,
                    ref: ref,
                    persona: persona,
                  ),
                );
                final historial = _HistorialPanel(
                  selectedId: parteVisible?.id,
                  onSelected: (parte) {
                    setState(() {
                      _parteSeleccionadoId = parte.id;
                    });
                  },
                  canAdmin: puedeAdmin,
                  busy: busy,
                  onAnular: (parte) => _anular(
                    context: context,
                    ref: ref,
                    parte: parte,
                  ),
                );
                final vista = ParteMedicoVistaPanel(
                  parte: parteVisible,
                  persona: personaVisible,
                );
                final lista = verRegistros ? historial : personas;

                if (constraints.maxWidth < 800) {
                  return Column(
                    children: [
                      Expanded(flex: 2, child: lista),
                      const SizedBox(height: 12),
                      Expanded(flex: 3, child: vista),
                    ],
                  );
                }
                return Row(
                  children: [
                    SizedBox(
                      width: (constraints.maxWidth * 0.38).clamp(300.0, 460.0),
                      child: lista,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: vista),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectorFechaPartes extends StatelessWidget {
  const _SelectorFechaPartes(
      {required this.fecha,
      required this.hoy,
      required this.busy,
      required this.onChanged});

  final DateTime fecha;
  final DateTime hoy;
  final bool busy;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Fecha de emisión'),
          IconButton(
            tooltip: 'Día anterior',
            onPressed: busy || !fecha.isAfter(DateTime(2000))
                ? null
                : () =>
                    onChanged(DateTime(fecha.year, fecha.month, fecha.day - 1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Tooltip(
            message: 'Elegir fecha de emisión',
            child: OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final elegida = await showDatePicker(
                        context: context,
                        initialDate: fecha.isAfter(hoy) ? hoy : fecha,
                        firstDate: DateTime(2000),
                        lastDate: hoy,
                        helpText: 'Fecha de emisión de los partes',
                        cancelText: 'Cancelar',
                        confirmText: 'Ver partes',
                      );
                      if (elegida != null && context.mounted) {
                        onChanged(elegida);
                      }
                    },
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(DateFmt.ddmmyyyy(fecha)),
            ),
          ),
          IconButton(
            tooltip: 'Día siguiente',
            onPressed: busy || !fecha.isBefore(hoy)
                ? null
                : () =>
                    onChanged(DateTime(fecha.year, fecha.month, fecha.day + 1)),
            icon: const Icon(Icons.chevron_right),
          ),
          TextButton(
            onPressed: busy || DateUtils.isSameDay(fecha, hoy)
                ? null
                : () => onChanged(hoy),
            child: const Text('Hoy'),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({super.key, required this.registros});

  final bool registros;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider =
        registros ? partesMedicosSearchProvider : medicosSearchProvider;
    return AppSearchField(
      key: ValueKey(registros),
      initialValue: ref.read(provider),
      labelText: registros
          ? 'Buscar parte por agente, DNI, legajo, familiar o aclaración'
          : 'Buscar persona por apellido, nombre, DNI o legajo',
      onChanged: (value) {
        ref.read(provider.notifier).state = value;
        if (!registros) {
          ref.read(selectedMedicoPersonaProvider.notifier).state = null;
        }
      },
    );
  }
}

class _PersonasPanel extends ConsumerWidget {
  final MedicoPersona? selected;
  final bool canCreate;
  final bool busy;
  final ValueChanged<MedicoPersona> onSelected;
  final ValueChanged<MedicoPersona> onEmitir;

  const _PersonasPanel({
    required this.selected,
    required this.canCreate,
    required this.busy,
    required this.onSelected,
    required this.onEmitir,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              'Todo el personal',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          Expanded(
            child: ref.watch(medicosPersonasProvider).when(
                  data: (items) => items.isEmpty
                      ? const Center(child: Text('Sin personas disponibles'))
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final persona = items[index];
                            return ListTile(
                              selected: selected?.dni == persona.dni,
                              leading: const CircleAvatar(
                                child: Icon(Icons.badge_outlined),
                              ),
                              title: Text(persona.nombreCompleto),
                              subtitle: Text(
                                '${persona.legajoLabel} - DNI ${persona.dni}',
                              ),
                              trailing: IconButton(
                                tooltip: 'Emitir parte',
                                onPressed: canCreate && !busy
                                    ? () => onEmitir(persona)
                                    : null,
                                icon: const Icon(Icons.print_outlined),
                              ),
                              onTap: () => onSelected(persona),
                            );
                          },
                        ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _InfoBox(
                    text: cleanError(e),
                    error: true,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

class _HistorialPanel extends ConsumerWidget {
  final int? selectedId;
  final ValueChanged<ParteMedico> onSelected;
  final bool canAdmin;
  final bool busy;
  final ValueChanged<ParteMedico> onAnular;

  const _HistorialPanel({
    required this.selectedId,
    required this.onSelected,
    required this.canAdmin,
    required this.busy,
    required this.onAnular,
  });

  Future<void> _reimprimir(
      BuildContext context, WidgetRef ref, ParteMedico parte) async {
    try {
      final domicilio = parte.domicilio ??
          (parte.tipo == TipoParteMedico.consultorio
              ? null
              : await ref.read(medicosDomicilioProvider(parte.dni).future));
      if (!context.mounted) return;
      final impreso =
          await ParteMedicoPrinter.imprimir(parte.conDomicilio(domicilio));
      if (impreso && context.mounted) {
        ref.read(colaImpresionProvider.notifier).quitar(parte.id);
      }
    } catch (e) {
      if (context.mounted) AppSnackBar.error(context, cleanError(e));
    }
  }

  Future<void> _listado(BuildContext context,
      Future<List<ParteMedico>> consulta, DateTime fecha) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => FutureBuilder<List<ParteMedico>>(
        future: consulta,
        builder: (_, snapshot) {
          final partes =
              snapshot.data?.where((parte) => parte.esEnfermeria).toList() ??
                  <ParteMedico>[];
          final texto = listadoParaEnfermeria(partes, fecha);
          return AlertDialog(
            title: const Text('Listado para Enfermería'),
            content: SizedBox(
                width: 620,
                child: snapshot.hasError
                    ? Text(
                        'No se pudo consultar la carrera del personal: ${cleanError(snapshot.error!)}')
                    : snapshot.connectionState != ConnectionState.done
                        ? const SizedBox(
                            height: 80,
                            child: Center(child: CircularProgressIndicator()))
                        : partes.isEmpty
                            ? const Text(
                                'No hay partes de la carrera Enfermería para esta fecha.')
                            : SingleChildScrollView(
                                child: SelectableText(texto))),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cerrar')),
              FilledButton.icon(
                onPressed: snapshot.connectionState != ConnectionState.done ||
                        snapshot.hasError ||
                        partes.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: texto));
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (context.mounted) {
                          AppSnackBar.success(context,
                              'Listado copiado para pegar en el correo.');
                        }
                      },
                icon: const Icon(Icons.copy),
                label: const Text('Copiar listado'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fecha = ref.watch(partesMedicosFechaProvider);
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              'Partes registrados',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                  'El listado incluye automáticamente a la carrera Enfermería.',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => _listado(
                        context,
                        ref.read(medicosRepoProvider).registros(fecha: fecha),
                        fecha),
                icon: const Icon(Icons.mail_outline),
                label: const Text('Listado de Enfermería'),
              ),
            ]),
          ),
          Expanded(
            child: ref.watch(partesMedicosPorDiaProvider).when(
                  data: (items) => items.isEmpty
                      ? const Center(child: Text('Sin partes registrados'))
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final parte = items[index];
                            final empiezaDia = index == 0 ||
                                !DateUtils.isSameDay(
                                    items[index - 1].fecha, parte.fecha);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (empiezaDia)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    child: Text(
                                      DateFmt.ddmmyyyy(parte.fecha),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ListTile(
                                  selected: selectedId == parte.id,
                                  onTap: () => onSelected(parte),
                                  leading: Tooltip(
                                    message:
                                        '${parte.tipo.label}${parte.esEnfermeria ? ' · Carrera Enfermería' : ''}',
                                    child: CircleAvatar(
                                      backgroundColor: parte.esEnfermeria
                                          ? Theme.of(context)
                                              .colorScheme
                                              .tertiaryContainer
                                          : null,
                                      child: Text(parte.tipo.codigo),
                                    ),
                                  ),
                                  title: Text(parte.descripcionRegistro),
                                  subtitle: Text(
                                    '${DateFmt.ddmmyyyy(parte.fecha)} - '
                                    '${parte.tipo.label}'
                                    '${parte.esArt ? ' - ART' : ''}'
                                    '${parte.esEnfermeria ? ' · Enfermería' : ''}',
                                  ),
                                  trailing: Wrap(
                                    spacing: 2,
                                    children: [
                                      IconButton(
                                        tooltip: 'Controlar devolución',
                                        onPressed: busy
                                            ? null
                                            : () => showDialog<void>(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  builder: (_) =>
                                                      ControlParteMedicoDialog(
                                                          parteId: parte.id),
                                                ),
                                        icon: const Icon(
                                            Icons.fact_check_outlined),
                                      ),
                                      IconButton(
                                        tooltip:
                                            'Agregar a la bandeja de impresión',
                                        onPressed: busy
                                            ? null
                                            : () async {
                                                try {
                                                  final domicilio = parte
                                                          .domicilio ??
                                                      (parte.tipo ==
                                                              TipoParteMedico
                                                                  .consultorio
                                                          ? null
                                                          : await ref.read(
                                                              medicosDomicilioProvider(
                                                                      parte.dni)
                                                                  .future));
                                                  if (!context.mounted) return;
                                                  ref
                                                      .read(
                                                          colaImpresionProvider
                                                              .notifier)
                                                      .agregar(
                                                          parte.conDomicilio(
                                                              domicilio));
                                                  AppSnackBar.success(context,
                                                      'Parte agregado a la bandeja');
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    AppSnackBar.error(
                                                        context, cleanError(e));
                                                  }
                                                }
                                              },
                                        icon: const Icon(Icons.playlist_add),
                                      ),
                                      IconButton(
                                        tooltip: 'Reimprimir',
                                        onPressed: busy
                                            ? null
                                            : () => _reimprimir(
                                                context, ref, parte),
                                        icon: const Icon(Icons.print_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'Anular',
                                        onPressed: canAdmin && !busy
                                            ? () => onAnular(parte)
                                            : null,
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _InfoBox(
                    text: cleanError(e),
                    error: true,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

class _ParteMedicoSubmission {
  final ParteMedicoFormData data;
  final bool imprimirAhora;

  const _ParteMedicoSubmission(this.data, {required this.imprimirAhora});
}

class _ParteMedicoDialog extends ConsumerStatefulWidget {
  final MedicoPersona persona;

  const _ParteMedicoDialog({required this.persona});

  @override
  ConsumerState<_ParteMedicoDialog> createState() => _ParteMedicoDialogState();
}

class _ParteMedicoDialogState extends ConsumerState<_ParteMedicoDialog> {
  TipoParteMedico _tipo = TipoParteMedico.domicilio;
  bool _esArt = false;
  MedicoFamiliar? _familiarSeleccionado;
  bool _edadEnMeses = false;
  final _fecha = DateTime.now();
  final _familiar = TextEditingController();
  final _familiarDni = TextEditingController();
  final _edad = TextEditingController();
  final _parentesco = TextEditingController();
  final _aclaracionFechaTurno = TextEditingController();
  String? _error;

  void _usarFamiliar(MedicoFamiliar? familiar) {
    setState(() {
      _familiarSeleccionado = familiar;
      _familiar.text = familiar?.apellidoNombre ?? '';
      _familiarDni.text = familiar?.dni?.toString() ?? '';
      final edadMeses = _mesesCumplidos(familiar?.fechaNacimiento, _fecha);
      _edadEnMeses = edadMeses != null && edadMeses < 12;
      _edad.text = _edadEnMeses
          ? edadMeses.toString()
          : familiar?.edad?.toString() ?? '';
      _parentesco.text = familiar?.parentesco ?? '';
      _error = null;
    });
  }

  @override
  void dispose() {
    _familiar.dispose();
    _familiarDni.dispose();
    _edad.dispose();
    _parentesco.dispose();
    _aclaracionFechaTurno.dispose();
    super.dispose();
  }

  Future<void> _submit({bool imprimirAhora = true}) async {
    final domicilioAsync =
        ref.read(medicosDomicilioProvider(widget.persona.dni));
    if (domicilioAsync.isLoading) return;
    if (domicilioAsync.hasError) {
      setState(() {
        _error =
            'No se pudo cargar el domicilio de la persona: ${cleanError(domicilioAsync.error!)}';
      });
      return;
    }
    final edadIngresada = int.tryParse(_edad.text.trim());
    final edadValida = edadIngresada != null &&
        (_edadEnMeses
            ? edadIngresada >= 0 && edadIngresada < 12
            : edadIngresada >= 0 && edadIngresada <= 120);
    final familiarDniTexto = _familiarDni.text.trim();
    final familiarDni = int.tryParse(familiarDniTexto);
    if (_tipo.requiereFamiliar &&
        (_familiar.text.trim().isEmpty ||
            !edadValida ||
            _parentesco.text.trim().isEmpty ||
            (familiarDniTexto.isNotEmpty &&
                (familiarDni == null || familiarDni <= 0)))) {
      setState(() {
        _error =
            'Revisa los datos del familiar, incluido su DNI si lo ingresaste.';
      });
      return;
    }

    final data = ParteMedicoFormData(
      dni: widget.persona.dni,
      fecha: _fecha,
      tipo: _tipo,
      familiarApellidoNombre:
          _tipo.requiereFamiliar ? _familiar.text.trim() : null,
      familiarDni: _tipo.requiereFamiliar ? familiarDni : null,
      familiarEdad: !_tipo.requiereFamiliar
          ? null
          : _edadEnMeses
              ? 0
              : edadIngresada,
      familiarEdadMeses:
          _tipo.requiereFamiliar && _edadEnMeses ? edadIngresada : null,
      familiarParentesco:
          _tipo.requiereFamiliar ? _parentesco.text.trim() : null,
      esArt: !_tipo.requiereFamiliar && _esArt,
      domicilio: domicilioAsync.valueOrNull,
      aclaracionFechaTurno: _aclaracionFechaTurno.text.trim().isEmpty
          ? null
          : _aclaracionFechaTurno.text.trim(),
    );
    if (!mounted) return;
    Navigator.pop(
        context, _ParteMedicoSubmission(data, imprimirAhora: imprimirAhora));
  }

  ParteMedico _crearParteVistaPrevia(MedicoDomicilio? domicilio) => ParteMedico(
        id: 0,
        dni: widget.persona.dni,
        fecha: _fecha,
        tipo: _tipo,
        empleadoApellido: widget.persona.apellido,
        empleadoNombre: widget.persona.nombre,
        empleadoLegajo: widget.persona.legajo,
        familiarApellidoNombre:
            _tipo.requiereFamiliar ? _familiar.text.trim() : null,
        familiarDni: _tipo.requiereFamiliar
            ? int.tryParse(_familiarDni.text.trim())
            : null,
        familiarEdad: _tipo.requiereFamiliar && !_edadEnMeses
            ? int.tryParse(_edad.text.trim())
            : _tipo.requiereFamiliar
                ? 0
                : null,
        familiarEdadMeses: _tipo.requiereFamiliar && _edadEnMeses
            ? int.tryParse(_edad.text.trim())
            : null,
        familiarParentesco:
            _tipo.requiereFamiliar ? _parentesco.text.trim() : null,
        esArt: !_tipo.requiereFamiliar && _esArt,
        domicilio: domicilio,
        aclaracionFechaTurno: _aclaracionFechaTurno.text.trim().isEmpty
            ? null
            : _aclaracionFechaTurno.text.trim(),
      );

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final colors = Theme.of(context).colorScheme;
    final domicilioAsync =
        ref.watch(medicosDomicilioProvider(widget.persona.dni));
    return AlertDialog(
      title: const Text('Emitir parte medico'),
      content: SizedBox(
        width: math.min(screen.width - 64, 1200),
        height: math.min(screen.height - 180, 720),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Tooltip(
                      message: 'DNI: ${widget.persona.dni}',
                      child: Text(
                        widget.persona.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (widget.persona.nombreCompleto.length > 65)
                      const _InfoBox(
                        text:
                            'El nombre se ajusta al espacio del formulario y puede recortarse. Revisa la vista previa antes de imprimir.',
                      ),
                    const SizedBox(height: 12),
                    domicilioAsync.when(
                      data: (domicilio) => _InfoBox(
                        text: domicilio == null || domicilio.estaVacio
                            ? 'Esta persona no tiene un domicilio vigente cargado.'
                            : 'Se incluirá el domicilio vigente en el parte, excepto para consultorio.',
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => _InfoBox(
                        text:
                            'No se pudo cargar el domicilio: ${cleanError(error)}',
                        error: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _aclaracionFechaTurno,
                      maxLength: 90,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Aclaración de fecha o turno (opcional)',
                        hintText: 'Ej.: 7/10 t.t, t.n o t.m',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha de emision',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(DateFmt.ddmmyyyy(_fecha)),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<TipoParteMedico>(
                      initialValue: _tipo,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de solicitud',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final tipo in TipoParteMedico.values)
                          DropdownMenuItem(
                              value: tipo, child: Text(tipo.label)),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _tipo = value;
                            if (!value.requiereFamiliar) {
                              _familiarSeleccionado = null;
                              _familiar.clear();
                              _familiarDni.clear();
                              _edad.clear();
                              _parentesco.clear();
                            } else {
                              _esArt = false;
                            }
                            _error = null;
                          });
                        }
                      },
                    ),
                    if (!_tipo.requiereFamiliar)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _esArt,
                        title: const Text('Es por ART'),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (value) {
                          setState(() {
                            _esArt = value ?? false;
                          });
                        },
                      ),
                    if (_tipo.requiereFamiliar) ...[
                      const SizedBox(height: 12),
                      ref
                          .watch(medicosFamiliaresProvider(widget.persona.dni))
                          .when(
                            data: (familiares) {
                              if (familiares.isEmpty) {
                                return const _InfoBox(
                                  text:
                                      'No hay familiares registrados. Podes completar los datos manualmente.',
                                );
                              }
                              return DropdownButtonFormField<MedicoFamiliar>(
                                key: ValueKey(_familiarSeleccionado?.id),
                                initialValue: _familiarSeleccionado,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Familiar registrado',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  for (final familiar in familiares)
                                    DropdownMenuItem(
                                      value: familiar,
                                      child: Text(
                                        familiar.label,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: _usarFamiliar,
                              );
                            },
                            loading: () => const LinearProgressIndicator(),
                            error: (e, _) => _InfoBox(
                              text:
                                  'No se pudieron cargar los familiares: ${cleanError(e)}',
                              error: true,
                            ),
                          ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _familiar,
                        decoration: const InputDecoration(
                          labelText: 'Apellido y nombre del familiar',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _familiarDni,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'DNI del familiar (opcional)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _edad,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Edad',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 100,
                            child: DropdownButtonFormField<bool>(
                              initialValue: _edadEnMeses,
                              decoration: const InputDecoration(
                                labelText: 'Unidad',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: false,
                                  child: Text('Años'),
                                ),
                                DropdownMenuItem(
                                  value: true,
                                  child: Text('Meses'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _edadEnMeses = value;
                                  _edad.clear();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _parentesco,
                              decoration: const InputDecoration(
                                labelText: 'Parentesco, ej. hijo o hija',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    const _InfoBox(
                      text:
                          'La impresion contiene solo los datos a superponer. Coloca el formulario preimpreso en la impresora.',
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.tune),
                      label: const Text('Ajustar impresión'),
                      onPressed: domicilioAsync.isLoading
                          ? null
                          : () async {
                              final saved = await showDialog<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => AjusteImpresionMedicaDialog(
                                  parte: _crearParteVistaPrevia(
                                      domicilioAsync.valueOrNull),
                                ),
                              );
                              if (!context.mounted || saved != true) return;
                              AppSnackBar.success(
                                  context, 'Ajuste de impresión guardado');
                            },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      _InfoBox(text: _error!, error: true),
                    ],
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 24),
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(
                      'Vista previa · ${_tipo.label}${_esArt ? ' · ART' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    )),
                    IconButton(
                      tooltip: 'Ampliar vista preliminar',
                      icon: const Icon(Icons.zoom_in),
                      onPressed:
                          domicilioAsync.isLoading || domicilioAsync.hasError
                              ? null
                              : () => mostrarVistaPreliminarAmpliada(
                                  context,
                                  _crearParteVistaPrevia(
                                      domicilioAsync.valueOrNull)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Expanded(
                    child: PdfPreview(
                      // Conservar el estado mantiene la hoja visible mientras
                      // el nuevo callback actualiza el PDF al editar los datos.
                      build: (_) => ParteMedicoPrinter.generarVistaPrevia(
                        _crearParteVistaPrevia(domicilioAsync.valueOrNull),
                      ),
                      initialPageFormat: PdfPageFormat.a4,
                      pageFormats: const {'A4': PdfPageFormat.a4},
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      canDebug: false,
                      useActions: false,
                      allowPrinting: false,
                      allowSharing: false,
                      maxPageWidth: 680,
                      padding: const EdgeInsets.all(8),
                      onError: (_, error) => Center(
                        child: Text(
                          'No se pudo generar la vista previa: $error',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        OutlinedButton.icon(
          onPressed: domicilioAsync.isLoading
              ? null
              : () => _submit(imprimirAhora: false),
          icon: const Icon(Icons.playlist_add),
          label: const Text('Cargar para imprimir después'),
        ),
        FilledButton.icon(
          onPressed: domicilioAsync.isLoading ? null : _submit,
          icon: const Icon(Icons.print),
          label: const Text('Registrar e imprimir'),
        ),
      ],
    );
  }
}

int? _mesesCumplidos(DateTime? fechaNacimiento, DateTime fechaReferencia) {
  if (fechaNacimiento == null) return null;
  var meses = (fechaReferencia.year - fechaNacimiento.year) * 12 +
      fechaReferencia.month -
      fechaNacimiento.month;
  if (fechaReferencia.day < fechaNacimiento.day) meses--;
  return meses;
}

class _InfoBox extends StatelessWidget {
  final String text;
  final bool error;

  const _InfoBox({required this.text, this.error = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? cs.errorContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: error ? cs.onErrorContainer : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

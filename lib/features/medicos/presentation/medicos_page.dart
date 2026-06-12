import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_snackbar.dart';
import '../../../core/utils/date_fmt.dart';
import '../../../core/utils/error_text.dart';
import '../application/medicos_providers.dart';
import '../data/parte_medico_printer.dart';
import '../domain/medico_persona.dart';
import '../domain/parte_medico.dart';

class MedicosPage extends ConsumerWidget {
  const MedicosPage({super.key});

  Future<void> _emitir({
    required BuildContext context,
    required WidgetRef ref,
    required MedicoPersona persona,
  }) async {
    final data = await showDialog<ParteMedicoFormData>(
      context: context,
      builder: (_) => _ParteMedicoDialog(persona: persona),
    );
    if (data == null) return;

    try {
      final id = await ref
          .read(guardarParteMedicoControllerProvider.notifier)
          .crear(data);
      final parte = ParteMedico(
        id: id,
        dni: persona.dni,
        fecha: DateTime.now(),
        tipo: data.tipo,
        empleadoApellido: persona.apellido,
        empleadoNombre: persona.nombre,
        empleadoLegajo: persona.legajo,
        familiarApellidoNombre: data.familiarApellidoNombre,
        familiarEdad: data.familiarEdad,
        familiarParentesco: data.familiarParentesco,
      );

      if (!context.mounted) return;
      AppSnackBar.success(context, 'Parte medico registrado');
      await ParteMedicoPrinter.imprimir(parte);
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.error(context, cleanError(e));
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
  Widget build(BuildContext context, WidgetRef ref) {
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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const _Toolbar(),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 900;
                final personas = _PersonasPanel(
                  selected: selected,
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
                  canAdmin: puedeAdmin,
                  busy: busy,
                  onAnular: (parte) => _anular(
                    context: context,
                    ref: ref,
                    parte: parte,
                  ),
                );

                if (compact) {
                  return Column(
                    children: [
                      SizedBox(height: 280, child: personas),
                      const SizedBox(height: 12),
                      Expanded(child: historial),
                    ],
                  );
                }
                return Row(
                  children: [
                    SizedBox(width: 390, child: personas),
                    const SizedBox(width: 16),
                    Expanded(child: historial),
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

class _Toolbar extends ConsumerStatefulWidget {
  const _Toolbar();

  @override
  ConsumerState<_Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends ConsumerState<_Toolbar> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _search,
      decoration: InputDecoration(
        labelText: 'Buscar por apellido, nombre, DNI o legajo',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpiar',
                onPressed: () {
                  _search.clear();
                  ref.read(medicosSearchProvider.notifier).state = '';
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
      ),
      onChanged: (value) {
        ref.read(medicosSearchProvider.notifier).state = value;
        ref.read(selectedMedicoPersonaProvider.notifier).state = null;
        setState(() {});
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
              'Personal con legajo',
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
                                'Legajo ${persona.legajo} - DNI ${persona.dni}',
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
  final bool canAdmin;
  final bool busy;
  final ValueChanged<ParteMedico> onAnular;

  const _HistorialPanel({
    required this.canAdmin,
    required this.busy,
    required this.onAnular,
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
              'Partes registrados',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          Expanded(
            child: ref.watch(partesMedicosProvider).when(
                  data: (items) => items.isEmpty
                      ? const Center(child: Text('Sin partes registrados'))
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final parte = items[index];
                            final familiar = parte.tipo.requiereFamiliar
                                ? ' - ${parte.familiarApellidoNombre}'
                                : '';
                            return ListTile(
                              leading: CircleAvatar(
                                child: Text(parte.fecha.day.toString()),
                              ),
                              title: Text(parte.empleadoCompleto),
                              subtitle: Text(
                                '${DateFmt.ddmmyyyy(parte.fecha)} - '
                                '${parte.tipo.label}$familiar',
                              ),
                              trailing: Wrap(
                                spacing: 2,
                                children: [
                                  IconButton(
                                    tooltip: 'Reimprimir',
                                    onPressed: busy
                                        ? null
                                        : () => ParteMedicoPrinter.imprimir(
                                              parte,
                                            ),
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

class _ParteMedicoDialog extends StatefulWidget {
  final MedicoPersona persona;

  const _ParteMedicoDialog({required this.persona});

  @override
  State<_ParteMedicoDialog> createState() => _ParteMedicoDialogState();
}

class _ParteMedicoDialogState extends State<_ParteMedicoDialog> {
  TipoParteMedico _tipo = TipoParteMedico.domicilio;
  final _familiar = TextEditingController();
  final _edad = TextEditingController();
  final _parentesco = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _familiar.dispose();
    _edad.dispose();
    _parentesco.dispose();
    super.dispose();
  }

  void _submit() {
    final edad = int.tryParse(_edad.text.trim());
    if (_tipo.requiereFamiliar &&
        (_familiar.text.trim().isEmpty ||
            edad == null ||
            edad < 0 ||
            edad > 120 ||
            _parentesco.text.trim().isEmpty)) {
      setState(() {
        _error = 'Completa nombre, edad y parentesco del familiar.';
      });
      return;
    }

    Navigator.pop(
      context,
      ParteMedicoFormData(
        dni: widget.persona.dni,
        tipo: _tipo,
        familiarApellidoNombre:
            _tipo.requiereFamiliar ? _familiar.text.trim() : null,
        familiarEdad: _tipo.requiereFamiliar ? edad : null,
        familiarParentesco:
            _tipo.requiereFamiliar ? _parentesco.text.trim() : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Emitir parte medico'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.persona.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (widget.persona.nombreCompleto.length > 65)
                const _InfoBox(
                  text:
                      'El apellido y nombre no entran en la linea del formulario y se dejaran en blanco para completar a mano.',
                ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha de emision',
                  border: OutlineInputBorder(),
                ),
                child: Text(DateFmt.ddmmyyyy(DateTime.now())),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TipoParteMedico>(
                initialValue: _tipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo de solicitud',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final tipo in TipoParteMedico.values)
                    DropdownMenuItem(value: tipo, child: Text(tipo.label)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _tipo = value;
                      _error = null;
                    });
                  }
                },
              ),
              if (_tipo.requiereFamiliar) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _familiar,
                  decoration: const InputDecoration(
                    labelText: 'Apellido y nombre del familiar',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 130,
                      child: TextField(
                        controller: _edad,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Edad',
                          border: OutlineInputBorder(),
                        ),
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
              if (_error != null) ...[
                const SizedBox(height: 8),
                _InfoBox(text: _error!, error: true),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save),
          label: const Text('Registrar e imprimir'),
        ),
      ],
    );
  }
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

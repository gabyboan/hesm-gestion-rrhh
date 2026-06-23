import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_snackbar.dart';
import '../../../core/utils/date_fmt.dart';
import '../../../core/utils/error_text.dart';
import '../application/imprevistos_providers.dart';
import '../domain/imprevisto_persona.dart';
import '../domain/imprevisto_registro.dart';

class ImprevistosPage extends ConsumerWidget {
  const ImprevistosPage({super.key});

  ImprevistoPersona? _resolveSelected(
    ImprevistoPersona? current,
    List<ImprevistoPersona> items,
  ) {
    if (items.isEmpty) return null;

    if (current != null) {
      final index = items.indexWhere((item) => item.key == current.key);
      if (index != -1) return items[index];
    }

    return items.first;
  }

  void _syncSelectedAfterBuild({
    required BuildContext context,
    required WidgetRef ref,
    required ImprevistoPersona? resolved,
    required ImprevistoPersona? current,
  }) {
    if (resolved == null) return;
    if (current?.key == resolved.key &&
        current?.usados == resolved.usados &&
        current?.restantes == resolved.restantes) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      final latest = ref.read(selectedImprevistoPersonaProvider);
      if (latest?.key == resolved.key &&
          latest?.usados == resolved.usados &&
          latest?.restantes == resolved.restantes) {
        return;
      }

      ref.read(selectedImprevistoPersonaProvider.notifier).state = resolved;
    });
  }

  Future<void> _openForm({
    required BuildContext context,
    required WidgetRef ref,
    required ImprevistoPersona persona,
    ImprevistoRegistro? registro,
  }) async {
    final anio = ref.read(imprevistosAnioProvider);
    final data = await showDialog<ImprevistoFormData>(
      context: context,
      builder: (_) => _ImprevistoFormDialog(
        persona: persona,
        anio: anio,
        registro: registro,
      ),
    );

    if (data == null) return;

    try {
      if (registro == null) {
        await ref
            .read(guardarImprevistoControllerProvider.notifier)
            .crear(data);
      } else {
        final ok = await ref
            .read(guardarImprevistoControllerProvider.notifier)
            .modificar(
              id: registro.id,
              data: data,
            );

        if (!ok) {
          throw Exception('El imprevisto no fue encontrado');
        }
      }

      if (!context.mounted) return;
      AppSnackBar.success(
        context,
        registro == null ? 'Imprevisto guardado' : 'Imprevisto modificado',
      );
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.error(context, cleanError(e));
    }
  }

  Future<void> _deleteRegistro({
    required BuildContext context,
    required WidgetRef ref,
    required ImprevistoRegistro registro,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Anular imprevisto'),
        content: Text(
          'Anular el imprevisto del ${DateFmt.ddmmyyyy(registro.fecha)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Anular'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final ok = await ref
          .read(eliminarImprevistoControllerProvider.notifier)
          .eliminar(
            id: registro.id,
          );

      if (!context.mounted) return;

      if (ok) {
        AppSnackBar.success(context, 'Imprevisto anulado');
      } else {
        AppSnackBar.error(context, 'El imprevisto no fue encontrado');
      }
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.error(context, cleanError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedImprevistoPersonaProvider);
    final guardarState = ref.watch(guardarImprevistoControllerProvider);
    final eliminarState = ref.watch(eliminarImprevistoControllerProvider);
    final puedeLeerAsync = ref.watch(puedeLeerImprevistosProvider);
    final puedeCargarAsync = ref.watch(puedeCargarImprevistosProvider);
    final puedeAdministrarAsync =
        ref.watch(puedeAdministrarImprevistosProvider);
    final busy = guardarState.isLoading || eliminarState.isLoading;
    final puedeLeer = puedeLeerAsync.valueOrNull ?? false;
    final puedeCargar = puedeCargarAsync.valueOrNull ?? false;
    final puedeAdministrar = puedeAdministrarAsync.valueOrNull ?? false;

    if (puedeLeerAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!puedeLeer) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: _InfoBox(
          text: 'Sin permiso para ver imprevistos. Falta IMPREVISTOS_LECTURA.',
          error: true,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const _ImprevistosToolbar(),
          const SizedBox(height: 12),
          Expanded(
            child: ref.watch(imprevistosListadoProvider).when(
                  data: (items) {
                    if (items.isEmpty) {
                      return const _InfoBox(
                        text: 'Sin personas disponibles para imprevistos.',
                      );
                    }

                    final resolved = _resolveSelected(selected, items);
                    _syncSelectedAfterBuild(
                      context: context,
                      ref: ref,
                      resolved: resolved,
                      current: selected,
                    );

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 860;

                        if (compact) {
                          return Column(
                            children: [
                              SizedBox(
                                height: 210,
                                child: _PersonasList(
                                  items: items,
                                  selectedKey: resolved?.key,
                                  onSelected: (persona) {
                                    ref
                                        .read(selectedImprevistoPersonaProvider
                                            .notifier)
                                        .state = persona;
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: _ImprevistoDetalle(
                                  persona: resolved,
                                  busy: busy,
                                  canCreate: puedeCargar,
                                  canAdmin: puedeAdministrar,
                                  onAdd: resolved == null
                                      ? null
                                      : () => _openForm(
                                            context: context,
                                            ref: ref,
                                            persona: resolved,
                                          ),
                                  onEdit: (registro) => _openForm(
                                    context: context,
                                    ref: ref,
                                    persona: resolved!,
                                    registro: registro,
                                  ),
                                  onDelete: (registro) => _deleteRegistro(
                                    context: context,
                                    ref: ref,
                                    registro: registro,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            SizedBox(
                              width: 380,
                              child: _PersonasList(
                                items: items,
                                selectedKey: resolved?.key,
                                onSelected: (persona) {
                                  ref
                                      .read(selectedImprevistoPersonaProvider
                                          .notifier)
                                      .state = persona;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _ImprevistoDetalle(
                                persona: resolved,
                                busy: busy,
                                canCreate: puedeCargar,
                                canAdmin: puedeAdministrar,
                                onAdd: resolved == null
                                    ? null
                                    : () => _openForm(
                                          context: context,
                                          ref: ref,
                                          persona: resolved,
                                        ),
                                onEdit: (registro) => _openForm(
                                  context: context,
                                  ref: ref,
                                  persona: resolved!,
                                  registro: registro,
                                ),
                                onDelete: (registro) => _deleteRegistro(
                                  context: context,
                                  ref: ref,
                                  registro: registro,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _InfoBox(
                    text: 'Error imprevistos: ${cleanError(e)}',
                    error: true,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

class _ImprevistosToolbar extends ConsumerStatefulWidget {
  const _ImprevistosToolbar();

  @override
  ConsumerState<_ImprevistosToolbar> createState() =>
      _ImprevistosToolbarState();
}

class _ImprevistosToolbarState extends ConsumerState<_ImprevistosToolbar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anio = ref.watch(imprevistosAnioProvider);

    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Anio anterior',
          onPressed: () {
            ref.read(imprevistosAnioProvider.notifier).state = anio - 1;
            ref.read(selectedImprevistoPersonaProvider.notifier).state = null;
          },
          icon: const Icon(Icons.chevron_left),
        ),
        SizedBox(
          width: 92,
          child: Center(
            child: Text(
              anio.toString(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Anio siguiente',
          onPressed: () {
            ref.read(imprevistosAnioProvider.notifier).state = anio + 1;
            ref.read(selectedImprevistoPersonaProvider.notifier).state = null;
          },
          icon: const Icon(Icons.chevron_right),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Buscar por DNI, apellido, nombre o carrera',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar',
                      onPressed: () {
                        _controller.clear();
                        ref.read(imprevistosSearchProvider.notifier).state = '';
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
            onChanged: (value) {
              ref.read(imprevistosSearchProvider.notifier).state = value;
              setState(() {});
            },
          ),
        ),
      ],
    );
  }
}

class _PersonasList extends StatelessWidget {
  final List<ImprevistoPersona> items;
  final String? selectedKey;
  final ValueChanged<ImprevistoPersona> onSelected;

  const _PersonasList({
    required this.items,
    required this.selectedKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final persona = items[index];
        final selected = persona.key == selectedKey;
        final agotado = persona.restantes <= 0;

        return ListTile(
          selected: selected,
          leading: CircleAvatar(
            backgroundColor: agotado
                ? cs.errorContainer
                : cs.primaryContainer.withValues(alpha: 0.8),
            foregroundColor:
                agotado ? cs.onErrorContainer : cs.onPrimaryContainer,
            child: Text(
              persona.restantes.toString(),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          title: Text('${persona.apellido}, ${persona.nombre}'),
          subtitle: Text('DNI ${persona.dni} - ${persona.carrera}'),
          trailing: selected ? const Icon(Icons.check_circle) : null,
          onTap: () => onSelected(persona),
        );
      },
    );
  }
}

class _ImprevistoDetalle extends ConsumerWidget {
  final ImprevistoPersona? persona;
  final bool busy;
  final bool canCreate;
  final bool canAdmin;
  final VoidCallback? onAdd;
  final ValueChanged<ImprevistoRegistro> onEdit;
  final ValueChanged<ImprevistoRegistro> onDelete;

  const _ImprevistoDetalle({
    required this.persona,
    required this.busy,
    required this.canCreate,
    required this.canAdmin,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = this.persona;

    if (persona == null) {
      return const _InfoBox(text: 'Selecciona una persona.');
    }

    final registros = ref.watch(imprevistosRegistrosProvider);
    final puedeCargar = canCreate && persona.restantes > 0 && !busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CupoHeader(
          persona: persona,
          busy: busy,
          canCreate: canCreate,
          onAdd: puedeCargar ? onAdd : null,
        ),
        if (!canCreate) ...[
          const SizedBox(height: 8),
          const _InfoBox(
            text: 'Sin permiso para cargar imprevistos.',
          ),
        ],
        if (persona.restantes <= 0) ...[
          const SizedBox(height: 8),
          const _InfoBox(
            text: 'La persona ya utilizo los 3 imprevistos del anio.',
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: registros.when(
            data: (rows) {
              if (rows.isEmpty) {
                return const Center(
                  child: Text('Sin imprevistos registrados en este anio'),
                );
              }

              return ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final registro = rows[index];
                  return _RegistroTile(
                    registro: registro,
                    enabled: canAdmin && !busy,
                    onEdit: () => onEdit(registro),
                    onDelete: () => onDelete(registro),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _InfoBox(
              text: 'Error registros: ${cleanError(e)}',
              error: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _CupoHeader extends StatelessWidget {
  final ImprevistoPersona persona;
  final bool busy;
  final bool canCreate;
  final VoidCallback? onAdd;

  const _CupoHeader({
    required this.persona,
    required this.busy,
    required this.canCreate,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    persona.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetricChip(
                        label: 'Usados',
                        value: persona.usados.toString(),
                        color: cs.primary,
                      ),
                      _MetricChip(
                        label: 'Restan',
                        value: persona.restantes.toString(),
                        color: persona.restantes <= 0 ? cs.error : Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: busy || !canCreate ? null : onAdd,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('Cargar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        child: Center(
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
      label: Text(label),
    );
  }
}

class _RegistroTile extends StatelessWidget {
  final ImprevistoRegistro registro;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RegistroTile({
    required this.registro,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final observation =
        registro.observacion.isEmpty ? 'Sin observacion' : registro.observacion;
    final orderText =
        registro.numeroOrden != null ? 'Orden ${registro.numeroOrden} - ' : '';

    return ListTile(
      leading: const CircleAvatar(
        child: Icon(Icons.event_busy_outlined),
      ),
      title: Text('$orderText${DateFmt.ddmmyyyy(registro.fecha)}'),
      subtitle: Text(observation),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'Modificar',
            onPressed: enabled ? onEdit : null,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Anular',
            onPressed: enabled ? onDelete : null,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _ImprevistoFormDialog extends StatefulWidget {
  final ImprevistoPersona persona;
  final int anio;
  final ImprevistoRegistro? registro;

  const _ImprevistoFormDialog({
    required this.persona,
    required this.anio,
    required this.registro,
  });

  @override
  State<_ImprevistoFormDialog> createState() => _ImprevistoFormDialogState();
}

class _ImprevistoFormDialogState extends State<_ImprevistoFormDialog> {
  late DateTime _fecha;
  late final TextEditingController _observacion;
  late final TextEditingController _numeroOrden;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    final registro = widget.registro;
    _fecha = registro?.fecha ??
        (now.year == widget.anio ? now : DateTime(widget.anio));
    _observacion = TextEditingController(text: registro?.observacion ?? '');
    _numeroOrden = TextEditingController(
      text: registro?.numeroOrden?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _observacion.dispose();
    _numeroOrden.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(widget.anio),
      lastDate: DateTime(widget.anio, 12, 31),
    );

    if (picked != null) {
      setState(() => _fecha = picked);
    }
  }

  void _submit() {
    final numeroOrdenText = _numeroOrden.text.trim();
    final numeroOrden =
        numeroOrdenText.isEmpty ? null : int.tryParse(numeroOrdenText);

    if (numeroOrdenText.isNotEmpty && numeroOrden == null) {
      AppSnackBar.error(context, 'Numero de orden debe ser un entero.');
      return;
    }

    Navigator.of(context).pop(
      ImprevistoFormData(
        dni: widget.persona.dni,
        carreraId: widget.persona.carreraId,
        fecha: _fecha,
        observacion:
            _observacion.text.trim().isEmpty ? null : _observacion.text.trim(),
        numeroOrden: numeroOrden,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.registro == null ? 'Cargar imprevisto' : 'Modificar imprevisto',
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.persona.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_month),
                ),
                child: Text(DateFmt.ddmmyyyy(_fecha)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _numeroOrden,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Numero de orden',
                border: OutlineInputBorder(),
                hintText: 'Opcional',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _observacion,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Observacion',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            const _InfoBox(
              text:
                  'Regla: maximo 3 por anio y no puede cargarse en dias consecutivos.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String text;
  final bool error;

  const _InfoBox({
    required this.text,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? cs.errorContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: error ? cs.onErrorContainer : cs.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

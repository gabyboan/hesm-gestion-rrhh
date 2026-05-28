import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/app_snackbar.dart';
import '../../../core/utils/date_fmt.dart';
import '../../../core/utils/error_text.dart';
import '../application/francos_providers.dart';
import '../domain/franco_movimiento.dart';
import '../domain/franco_persona.dart';

class FrancosPage extends ConsumerWidget {
  const FrancosPage({super.key});

  FrancoPersona? _resolveSelected(
    FrancoPersona? current,
    List<FrancoPersona> items,
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
    required FrancoPersona? resolved,
    required FrancoPersona? current,
  }) {
    if (resolved == null) return;
    if (current?.key == resolved.key && current?.saldo == resolved.saldo) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      final latest = ref.read(selectedFrancoPersonaProvider);
      if (latest?.key == resolved.key && latest?.saldo == resolved.saldo) {
        return;
      }

      ref.read(selectedFrancoPersonaProvider.notifier).state = resolved;
    });
  }

  Future<void> _openForm({
    required BuildContext context,
    required WidgetRef ref,
    required FrancoPersona persona,
    required _FrancoFormMode mode,
    FrancoMovimiento? movimiento,
  }) async {
    final data = await showDialog<FrancoFormData>(
      context: context,
      builder: (_) {
        return _FrancoFormDialog(
          persona: persona,
          mode: mode,
          movimiento: movimiento,
        );
      },
    );

    if (data == null) return;

    try {
      if (movimiento == null) {
        await ref.read(guardarFrancoControllerProvider.notifier).crear(data);
      } else {
        await ref.read(guardarFrancoControllerProvider.notifier).modificar(
              id: movimiento.id,
              data: data,
            );
      }

      if (!context.mounted) return;
      AppSnackBar.success(context, 'Franco guardado');
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.error(context, cleanError(e));
    }
  }

  Future<void> _deleteMovimiento({
    required BuildContext context,
    required WidgetRef ref,
    required FrancoMovimiento movimiento,
  }) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => const _DeleteFrancoDialog(),
    );

    if (motivo == null) return;

    try {
      final ok =
          await ref.read(eliminarFrancoControllerProvider.notifier).eliminar(
                id: movimiento.id,
                motivo: motivo,
              );

      if (!context.mounted) return;

      if (ok) {
        AppSnackBar.success(context, 'Movimiento anulado');
      } else {
        AppSnackBar.error(context, 'El movimiento no fue encontrado');
      }
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.error(context, cleanError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listado = ref.watch(francosListadoProvider);
    final selected = ref.watch(selectedFrancoPersonaProvider);
    final guardarState = ref.watch(guardarFrancoControllerProvider);
    final eliminarState = ref.watch(eliminarFrancoControllerProvider);
    final busy = guardarState.isLoading || eliminarState.isLoading;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const _FrancosSearchBar(),
          const SizedBox(height: 12),
          Expanded(
            child: listado.when(
              data: (items) {
                if (items.isEmpty) {
                  return const _InfoBox(
                    text: 'Sin personas disponibles o sin permiso.',
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
                    final compact = constraints.maxWidth < 840;

                    if (compact) {
                      return Column(
                        children: [
                          SizedBox(
                            height: 190,
                            child: _PersonasList(
                              items: items,
                              selectedKey: resolved?.key,
                              onSelected: (persona) {
                                ref
                                    .read(
                                        selectedFrancoPersonaProvider.notifier)
                                    .state = persona;
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _FrancoDetalle(
                              persona: resolved,
                              busy: busy,
                              onAdd: resolved == null
                                  ? null
                                  : () => _openForm(
                                        context: context,
                                        ref: ref,
                                        persona: resolved,
                                        mode: _FrancoFormMode.add,
                                      ),
                              onSubtract: resolved == null
                                  ? null
                                  : () => _openForm(
                                        context: context,
                                        ref: ref,
                                        persona: resolved,
                                        mode: _FrancoFormMode.subtract,
                                      ),
                              onEdit: (movimiento) => _openForm(
                                context: context,
                                ref: ref,
                                persona: resolved!,
                                mode: movimiento.cantidad > 0
                                    ? _FrancoFormMode.add
                                    : _FrancoFormMode.subtract,
                                movimiento: movimiento,
                              ),
                              onDelete: (movimiento) => _deleteMovimiento(
                                context: context,
                                ref: ref,
                                movimiento: movimiento,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        SizedBox(
                          width: 360,
                          child: _PersonasList(
                            items: items,
                            selectedKey: resolved?.key,
                            onSelected: (persona) {
                              ref
                                  .read(selectedFrancoPersonaProvider.notifier)
                                  .state = persona;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _FrancoDetalle(
                            persona: resolved,
                            busy: busy,
                            onAdd: resolved == null
                                ? null
                                : () => _openForm(
                                      context: context,
                                      ref: ref,
                                      persona: resolved,
                                      mode: _FrancoFormMode.add,
                                    ),
                            onSubtract: resolved == null
                                ? null
                                : () => _openForm(
                                      context: context,
                                      ref: ref,
                                      persona: resolved,
                                      mode: _FrancoFormMode.subtract,
                                    ),
                            onEdit: (movimiento) => _openForm(
                              context: context,
                              ref: ref,
                              persona: resolved!,
                              mode: movimiento.cantidad > 0
                                  ? _FrancoFormMode.add
                                  : _FrancoFormMode.subtract,
                              movimiento: movimiento,
                            ),
                            onDelete: (movimiento) => _deleteMovimiento(
                              context: context,
                              ref: ref,
                              movimiento: movimiento,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _InfoBox(
                text: 'Error francos: ${cleanError(e)}',
                error: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FrancosSearchBar extends ConsumerStatefulWidget {
  const _FrancosSearchBar();

  @override
  ConsumerState<_FrancosSearchBar> createState() => _FrancosSearchBarState();
}

class _FrancosSearchBarState extends ConsumerState<_FrancosSearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
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
                  ref.read(francosSearchProvider.notifier).state = '';
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
      ),
      onChanged: (value) {
        ref.read(francosSearchProvider.notifier).state = value;
        setState(() {});
      },
    );
  }
}

class _PersonasList extends StatelessWidget {
  final List<FrancoPersona> items;
  final String? selectedKey;
  final ValueChanged<FrancoPersona> onSelected;

  const _PersonasList({
    required this.items,
    required this.selectedKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final persona = items[index];
        final selected = persona.key == selectedKey;

        return ListTile(
          selected: selected,
          leading: CircleAvatar(
            child: Text(persona.saldo.toString()),
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

class _FrancoDetalle extends ConsumerWidget {
  final FrancoPersona? persona;
  final bool busy;
  final VoidCallback? onAdd;
  final VoidCallback? onSubtract;
  final ValueChanged<FrancoMovimiento> onEdit;
  final ValueChanged<FrancoMovimiento> onDelete;

  const _FrancoDetalle({
    required this.persona,
    required this.busy,
    required this.onAdd,
    required this.onSubtract,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = this.persona;

    if (persona == null) {
      return const _InfoBox(text: 'Selecciona una persona.');
    }

    final movimientos = ref.watch(francosMovimientosProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SaldoHeader(
          persona: persona,
          busy: busy,
          onAdd: onAdd,
          onSubtract: onSubtract,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: movimientos.when(
            data: (rows) {
              if (rows.isEmpty) {
                return const Center(
                  child: Text('Sin movimientos de francos'),
                );
              }

              return ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final movimiento = rows[index];
                  return _MovimientoTile(
                    movimiento: movimiento,
                    busy: busy,
                    onEdit: () => onEdit(movimiento),
                    onDelete: () => onDelete(movimiento),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _InfoBox(
              text: 'Error movimientos: ${cleanError(e)}',
              error: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _SaldoHeader extends StatelessWidget {
  final FrancoPersona persona;
  final bool busy;
  final VoidCallback? onAdd;
  final VoidCallback? onSubtract;

  const _SaldoHeader({
    required this.persona,
    required this.busy,
    required this.onAdd,
    required this.onSubtract,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final saldoColor = persona.saldo < 0 ? cs.error : cs.primary;

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
                  const SizedBox(height: 6),
                  Text(
                    'Saldo: ${persona.saldo}',
                    style: TextStyle(
                      color: saldoColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              tooltip: 'Sumar franco',
              onPressed: busy ? null : onAdd,
              icon: const Icon(Icons.add),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Restar franco',
              onPressed: busy ? null : onSubtract,
              icon: const Icon(Icons.remove),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovimientoTile extends StatelessWidget {
  final FrancoMovimiento movimiento;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MovimientoTile({
    required this.movimiento,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final positive = movimiento.cantidad > 0;
    final color = positive ? Colors.green.shade700 : cs.error;
    final sign = positive ? '+' : '';
    final loadedAt =
        DateFormat('dd/MM/yyyy HH:mm').format(movimiento.createdAt);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        child: Text('$sign${movimiento.cantidad}'),
      ),
      title: Text(
        '${DateFmt.ddmmyyyy(movimiento.fecha)} - ${movimiento.motivo}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          if (movimiento.observacion.isNotEmpty) movimiento.observacion,
          'Cargado por ${movimiento.usuarioCargaLabel} el $loadedAt',
        ].join('\n'),
      ),
      isThreeLine: movimiento.observacion.isNotEmpty,
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'Modificar',
            onPressed: busy ? null : onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Anular',
            onPressed: busy ? null : onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

enum _FrancoFormMode {
  add,
  subtract,
}

class _FrancoFormDialog extends StatefulWidget {
  final FrancoPersona persona;
  final _FrancoFormMode mode;
  final FrancoMovimiento? movimiento;

  const _FrancoFormDialog({
    required this.persona,
    required this.mode,
    required this.movimiento,
  });

  @override
  State<_FrancoFormDialog> createState() => _FrancoFormDialogState();
}

class _FrancoFormDialogState extends State<_FrancoFormDialog> {
  late DateTime _fecha;
  late final TextEditingController _cantidad;
  late final TextEditingController _motivo;
  late final TextEditingController _observacion;

  bool get _isEdit => widget.movimiento != null;
  bool get _isSubtract => widget.mode == _FrancoFormMode.subtract;

  @override
  void initState() {
    super.initState();

    final movimiento = widget.movimiento;
    _fecha = movimiento?.fecha ?? DateTime.now();
    _cantidad = TextEditingController(
      text: (movimiento?.cantidad.abs() ?? 1).toString(),
    );
    _motivo = TextEditingController(
      text: movimiento?.motivo ?? (_isSubtract ? 'Uso de franco' : 'Alta'),
    );
    _observacion = TextEditingController(
      text: movimiento?.observacion ?? '',
    );
  }

  @override
  void dispose() {
    _cantidad.dispose();
    _motivo.dispose();
    _observacion.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      setState(() => _fecha = picked);
    }
  }

  void _submit() {
    final cantidadAbs = int.tryParse(_cantidad.text.trim());
    final motivo = _motivo.text.trim();
    final observacion = _observacion.text.trim();

    if (cantidadAbs == null || cantidadAbs <= 0) {
      AppSnackBar.error(context, 'Ingresa una cantidad mayor a cero');
      return;
    }

    if (motivo.isEmpty) {
      AppSnackBar.error(context, 'Ingresa un motivo');
      return;
    }

    final signed = _isSubtract ? -cantidadAbs : cantidadAbs;

    Navigator.of(context).pop(
      FrancoFormData(
        dni: widget.persona.dni,
        carreraId: widget.persona.carreraId,
        fecha: _fecha,
        cantidad: signed,
        motivo: motivo,
        observacion: observacion.isEmpty ? null : observacion,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit
        ? 'Modificar franco'
        : _isSubtract
            ? 'Restar franco'
            : 'Sumar franco';

    return AlertDialog(
      title: Text(title),
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
              controller: _cantidad,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cantidad',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _motivo,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _observacion,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observacion',
                border: OutlineInputBorder(),
              ),
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

class _DeleteFrancoDialog extends StatefulWidget {
  const _DeleteFrancoDialog();

  @override
  State<_DeleteFrancoDialog> createState() => _DeleteFrancoDialogState();
}

class _DeleteFrancoDialogState extends State<_DeleteFrancoDialog> {
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Anular movimiento'),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _motivo,
          autofocus: true,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo de anulacion',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => Navigator.of(context).pop(_motivo.text.trim()),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Anular'),
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

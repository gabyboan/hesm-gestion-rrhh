// lib/features/horas/presentation/cargar/cargar_horas_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_fmt.dart';
import '../../application/horas_providers.dart';
import '../../domain/persona.dart';
import '../../domain/tipo_hora.dart';
import 'widgets/pick_duracion_30.dart';

class CargarHorasPage extends ConsumerWidget {
  const CargarHorasPage({super.key});

  Future<DateTime?> _pickDate(BuildContext context, DateTime initial) {
    final now = DateTime.now();

    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
  }

  Persona? _resolveSelectedPersona(Persona? current, List<Persona> items) {
    if (items.isEmpty) return null;

    if (current != null) {
      final idx = items.indexWhere((p) => p.key == current.key);
      if (idx != -1) return items[idx];
    }

    return items.first;
  }

  void _syncSelectedPersonaAfterBuild({
    required BuildContext context,
    required WidgetRef ref,
    required Persona resolved,
    required Persona? current,
  }) {
    if (current?.key == resolved.key) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      final latest = ref.read(selectedPersonaProvider);
      if (latest?.key == resolved.key) return;

      ref.read(selectedPersonaProvider.notifier).state = resolved;
    });
  }

  void _showMessage(
    BuildContext context,
    String message, {
    bool error = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? cs.error : Colors.green.shade700,
      ),
    );
  }

  String _errorMessage(Object e) {
    final raw = e.toString().trim();

    if (raw.isEmpty) {
      return 'No se pudo guardar.';
    }

    final postgresMessage = _extractPostgrestMessage(raw);
    final msg = (postgresMessage ?? raw).replaceFirst('Exception: ', '').trim();

    final lower = msg.toLowerCase();

    if (lower.contains('enfermedad') &&
        lower.contains('solo 1 registro por mes')) {
      return 'Ya existe un registro de enfermedad para esta persona en este mes.';
    }

    if (lower.contains('solo 1 registro por mes')) {
      return 'Ya existe un registro para esta persona en este mes.';
    }

    return msg;
  }

  String? _extractPostgrestMessage(String raw) {
    // Ejemplo:
    // PostgrestException(message: ENFERMEDAD: solo 1 registro por mes (...).,
    // code: P0001, details: Bad Request, hint: null)
    final match = RegExp(
      r'PostgrestException\(message:\s*(.*?),\s*code:',
      dotAll: true,
    ).firstMatch(raw);

    final message = match?.group(1)?.trim();
    if (message == null || message.isEmpty) return null;

    return message;
  }

  Future<void> _pickPersonaModal(
    BuildContext context,
    WidgetRef ref,
    List<Persona> items,
  ) async {
    final current = ref.read(selectedPersonaProvider);

    final picked = await showModalBottomSheet<Persona>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) {
        return _PersonaPickerSheet(
          items: items,
          selectedKey: current?.key,
        );
      },
    );

    if (picked != null) {
      ref.read(selectedPersonaProvider.notifier).state = picked;
    }
  }

  Future<void> _pickDuracionOficial(
    BuildContext context,
    WidgetRef ref,
    int? currentMinutes,
  ) async {
    final picked = await pickDuracion30Hasta10hs(
      context,
      initialMinutes: currentMinutes ?? 60,
    );

    if (picked != null) {
      ref.read(minutosProvider.notifier).state = picked;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listado = ref.watch(listadoSegunTipoProvider);

    final persona = ref.watch(selectedPersonaProvider);
    final fecha = ref.watch(fechaProvider);
    final tipo = ref.watch(tipoHoraProvider);
    final minutos = ref.watch(minutosProvider);
    final submitState = ref.watch(cargarHoraControllerProvider);

    final canGuardar = !submitState.isLoading &&
        persona != null &&
        (!tipo.requiereMinutos || minutos != null);

    Future<void> guardar() async {
      try {
        await ref.read(cargarHoraControllerProvider.notifier).submit();

        if (!context.mounted) return;
        _showMessage(context, 'Guardado con éxito');
      } catch (e) {
        if (!context.mounted) return;
        _showMessage(context, _errorMessage(e), error: true);
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const Text(
            'Cargar horas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          listado.when(
            data: (items) {
              if (items.isEmpty) {
                return const _InfoBox(
                  text: 'Sin personas en el listado o sin permiso.',
                );
              }

              final selected = _resolveSelectedPersona(persona, items);

              if (selected == null) {
                return const _InfoBox(
                  text: 'No hay una persona seleccionable.',
                );
              }

              _syncSelectedPersonaAfterBuild(
                context: context,
                ref: ref,
                resolved: selected,
                current: persona,
              );

              return _PersonaSelectorField(
                persona: selected,
                onTap: () => _pickPersonaModal(context, ref, items),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => _InfoBox(
              text: 'Error listado: ${_errorMessage(e)}',
              error: true,
            ),
          ),
          const SizedBox(height: 12),
          _DateSelectorField(
            fecha: fecha,
            onTap: () async {
              final picked = await _pickDate(context, fecha);
              if (picked != null) {
                ref.read(fechaProvider.notifier).state = picked;
              }
            },
          ),
          const SizedBox(height: 12),
          _TipoHoraSelector(
            selected: tipo,
            onChanged: (selected) {
              ref.read(tipoHoraProvider.notifier).state = selected;

              // Al cambiar de tipo se fuerza una nueva selección de minutos.
              // En mobile no abrimos pickers automáticamente.
              ref.read(minutosProvider.notifier).state = null;
            },
          ),
          const SizedBox(height: 16),
          if (tipo.requiereMinutos) ...[
            Text(
              tipo == TipoHora.oficial ? 'Duración' : 'Minutos',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            if (tipo == TipoHora.oficial)
              _DuracionOficialField(
                minutos: minutos,
                onTap: () => _pickDuracionOficial(
                  context,
                  ref,
                  minutos,
                ),
              )
            else
              _MinutosParticularesChips(
                selected: minutos,
                onSelected: (value) {
                  ref.read(minutosProvider.notifier).state = value;
                },
              ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: canGuardar ? guardar : null,
              icon: submitState.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Guardar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonaSelectorField extends StatelessWidget {
  final Persona persona;
  final VoidCallback onTap;

  const _PersonaSelectorField({
    required this.persona,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Apellido y nombre',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.expand_more),
        ),
        child: Text(
          persona.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _DateSelectorField extends StatelessWidget {
  final DateTime fecha;
  final VoidCallback onTap;

  const _DateSelectorField({
    required this.fecha,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Fecha (DD/MM/AAAA)',
          border: OutlineInputBorder(),
        ),
        child: Row(
          children: [
            Expanded(child: Text(DateFmt.ddmmyyyy(fecha))),
            const Icon(Icons.calendar_month),
          ],
        ),
      ),
    );
  }
}

class _TipoHoraSelector extends StatelessWidget {
  final TipoHora selected;
  final ValueChanged<TipoHora> onChanged;

  const _TipoHoraSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TipoHora>(
      showSelectedIcon: false,
      segments: [
        for (final tipo in TipoHora.values)
          ButtonSegment<TipoHora>(
            value: tipo,
            label: Text(tipo.label),
          ),
      ],
      selected: {selected},
      onSelectionChanged: (selection) {
        if (selection.isEmpty) return;
        onChanged(selection.first);
      },
    );
  }
}

class _MinutosParticularesChips extends StatelessWidget {
  final int? selected;
  final ValueChanged<int> onSelected;

  const _MinutosParticularesChips({
    required this.selected,
    required this.onSelected,
  });

  static const _options = <int>[
    30,
    60,
    90,
    120,
    150,
    180,
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final minutes in _options)
          ChoiceChip(
            selected: selected == minutes,
            onSelected: (_) => onSelected(minutes),
            label: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              child: Text(
                _labelMinutosLargo(minutes),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
      ],
    );
  }

  String _labelMinutosLargo(int min) {
    final h = min ~/ 60;
    final m = min % 60;

    if (h == 0) return '$m minutos';
    if (m == 0) return '$h hora${h == 1 ? '' : 's'}';

    return '$h hora${h == 1 ? '' : 's'} y $m minutos';
  }
}

class _DuracionOficialField extends StatelessWidget {
  final int? minutos;
  final VoidCallback onTap;

  const _DuracionOficialField({
    required this.minutos,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = minutos == null
        ? 'Seleccionar duración'
        : 'Duración: ${labelMinutos30(minutos!)}';

    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontWeight: minutos == null ? FontWeight.w500 : null,
                ),
              ),
            ),
            const Icon(Icons.schedule),
          ],
        ),
      ),
    );
  }
}

class _PersonaPickerSheet extends StatefulWidget {
  final List<Persona> items;
  final String? selectedKey;

  const _PersonaPickerSheet({
    required this.items,
    required this.selectedKey,
  });

  @override
  State<_PersonaPickerSheet> createState() => _PersonaPickerSheetState();
}

class _PersonaPickerSheetState extends State<_PersonaPickerSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _matches(Persona p, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    final values = [
      p.dni.toString(),
      p.apellido,
      p.nombre,
      p.carrera,
      p.label,
      p.key,
    ];

    return values.any((value) => value.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items.where((p) {
      return _matches(p, _controller.text);
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.52,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
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
                            setState(() {});
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('Sin resultados'))
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final p = filtered[index];
                          final selected = p.key == widget.selectedKey;

                          return ListTile(
                            title: Text('${p.apellido}, ${p.nombre}'),
                            subtitle: Text(
                              'DNI: ${p.dni} · Carrera: ${p.carrera}',
                            ),
                            trailing: selected
                                ? const Icon(Icons.check_circle)
                                : null,
                            onTap: () => Navigator.of(context).pop(p),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
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

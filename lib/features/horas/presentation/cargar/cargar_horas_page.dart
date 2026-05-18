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

  bool _matchPersona(Persona p, String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return true;

    final dni = p.dni.toString();
    final ape = p.apellido.toLowerCase();
    final nom = p.nombre.toLowerCase();
    final label = p.label.toLowerCase();

    return dni.contains(s) ||
        ape.contains(s) ||
        nom.contains(s) ||
        label.contains(s);
  }

  void _showGuardadoPopup(BuildContext context, String msg,
      {bool err = false}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => Material(
        color: Colors.black.withOpacity(0.15),
        child: Center(
          child: IgnorePointer(
            child: Container(
              constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              decoration: BoxDecoration(
                color: err ? Colors.red.shade600 : Colors.green.shade600,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 18,
                    color: Colors.black26,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);

    Future.delayed(const Duration(milliseconds: 1800), () {
      entry.remove();
    });
  }

  Future<void> _pickPersonaModal(
    BuildContext context,
    WidgetRef ref,
    List<Persona> items,
  ) async {
    final picked = await showModalBottomSheet<Persona>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final controller = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setState) {
            final q = controller.text;
            final filtered = items.where((p) => _matchPersona(p, q)).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.75,
                  child: Column(
                    children: [
                      TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'Buscar (DNI / Apellido / Nombre)',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: q.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpiar',
                                  onPressed: () {
                                    controller.clear();
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
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final p = filtered[i];
                                  return ListTile(
                                    title: Text('${p.apellido}, ${p.nombre}'),
                                    subtitle: Text('DNI: ${p.dni}'),
                                    onTap: () => Navigator.pop(ctx, p),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (picked != null) {
      ref.read(selectedPersonaProvider.notifier).state = picked;
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

    Widget tipoButtons() {
      return SegmentedButton<TipoHora>(
        segments: const [
          ButtonSegment(value: TipoHora.particular, label: Text('Particular')),
          ButtonSegment(value: TipoHora.enfermedad, label: Text('Enfermedad')),
          ButtonSegment(value: TipoHora.oficial, label: Text('Oficial')),
        ],
        selected: {tipo},
        onSelectionChanged: (s) async {
          final selected = s.first;

          ref.read(tipoHoraProvider.notifier).state = selected;
          ref.read(minutosProvider.notifier).state = null;

          if (selected == TipoHora.oficial) {
            final current = minutos ?? 60;
            final picked = await pickDuracion30Hasta10hs(
              context,
              initialMinutes: current,
            );
            if (picked != null) {
              ref.read(minutosProvider.notifier).state = picked;
            }
          }
        },
      );
    }

    Widget minutosButtons({required bool centered}) {
      const opts = [30, 60, 90, 120, 150, 180];

      String label(int min) {
        final h = min ~/ 60;
        final m = min % 60;

        if (h == 0) return '$m minutos';
        if (m == 0) return '$h hora${h == 1 ? '' : 's'}';
        return '$h hora${h == 1 ? '' : 's'} y $m minutos';
      }

      return Wrap(
        alignment: centered ? WrapAlignment.center : WrapAlignment.start,
        runAlignment: centered ? WrapAlignment.center : WrapAlignment.start,
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final m in opts)
            ChoiceChip(
              selected: minutos == m,
              onSelected: (_) => ref.read(minutosProvider.notifier).state = m,
              label: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Text(
                  label(m),
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

    Future<void> guardar() async {
      try {
        await ref.read(cargarHoraControllerProvider.notifier).submit();
        _showGuardadoPopup(context, 'Guardado con éxito');
      } catch (e) {
        _showGuardadoPopup(context, 'Error: $e', err: true);
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Text(
            'Cargar horas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          listado.when(
            data: (items) {
              if (items.isEmpty) {
                return const Text(
                  'Sin personas en el listado (o sin permiso).',
                );
              }

              Persona selected;
              if (persona == null) {
                selected = items.first;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(selectedPersonaProvider.notifier).state = selected;
                });
              } else {
                final idx = items.indexWhere((p) => p.dni == persona.dni);
                if (idx == -1) {
                  selected = items.first;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(selectedPersonaProvider.notifier).state = selected;
                  });
                } else {
                  selected = items[idx];
                }
              }

              return InkWell(
                onTap: () => _pickPersonaModal(context, ref, items),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Apellido y nombre',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.expand_more),
                  ),
                  child: Text(selected.label),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error listado: $e'),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final d = await _pickDate(context, fecha);
              if (d != null) {
                ref.read(fechaProvider.notifier).state = d;
              }
            },
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
          ),
          const SizedBox(height: 12),
          tipoButtons(),
          const SizedBox(height: 16),
          if (tipo.requiereMinutos) ...[
            const Text(
              'Minutos',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            if (tipo == TipoHora.oficial)
              InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        minutos == null
                            ? 'Seleccioná una duración'
                            : 'Duración: ${labelMinutos30(minutos)}',
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cambiar duración',
                      onPressed: () async {
                        final current = minutos ?? 60;
                        final picked = await pickDuracion30Hasta10hs(
                          context,
                          initialMinutes: current,
                        );
                        if (picked != null) {
                          ref.read(minutosProvider.notifier).state = picked;
                        }
                      },
                      icon: const Icon(Icons.edit),
                    ),
                  ],
                ),
              )
            else
              minutosButtons(centered: tipo == TipoHora.particular),
            const SizedBox(height: 16),
          ],
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: submitState.isLoading ? null : guardar,
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

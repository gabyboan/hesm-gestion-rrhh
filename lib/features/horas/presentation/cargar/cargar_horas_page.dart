// lib/features/horas/presentation/cargar/cargar_horas_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/app_snackbar.dart';
import '../../application/horas_providers.dart';
import '../../domain/persona.dart';
import '../../domain/tipo_hora.dart';
import 'widgets/cargar_horas_widgets.dart';
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
        return CargarPersonaPickerSheet(
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
        AppSnackBar.success(context, 'Guardado correctamente');
      } catch (e) {
        if (!context.mounted) return;
        AppSnackBar.error(context, 'No guardado: ${_errorMessage(e)}');
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
                return const CargarInfoBox(
                  text: 'Sin personas en el listado o sin permiso.',
                );
              }

              final selected = _resolveSelectedPersona(persona, items);

              if (selected == null) {
                return const CargarInfoBox(
                  text: 'No hay una persona seleccionable.',
                );
              }

              _syncSelectedPersonaAfterBuild(
                context: context,
                ref: ref,
                resolved: selected,
                current: persona,
              );

              return CargarPersonaSelectorField(
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
            error: (e, _) => CargarInfoBox(
              text: 'Error listado: ${_errorMessage(e)}',
              error: true,
            ),
          ),
          const SizedBox(height: 12),
          CargarDateSelectorField(
            fecha: fecha,
            onTap: () async {
              final picked = await _pickDate(context, fecha);
              if (picked != null) {
                ref.read(fechaProvider.notifier).state = picked;
              }
            },
          ),
          const SizedBox(height: 12),
          TipoHoraSelector(
            selected: tipo,
            onChanged: (selected) {
              ref.read(tipoHoraProvider.notifier).state = selected;
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
              DuracionOficialField(
                minutos: minutos,
                onTap: () => _pickDuracionOficial(
                  context,
                  ref,
                  minutos,
                ),
              )
            else
              MinutosParticularesChips(
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

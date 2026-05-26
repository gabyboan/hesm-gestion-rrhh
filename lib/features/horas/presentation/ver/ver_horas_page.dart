// lib/features/horas/presentation/ver/ver_horas_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/app_snackbar.dart';
import '../../../../core/utils/date_fmt.dart';
import '../../../../core/utils/error_text.dart';
import '../../application/horas_providers.dart';
import '../../domain/hora_registro.dart';
import '../../domain/persona.dart';
import 'widgets/ver_horas_widgets.dart';

class VerHorasPage extends ConsumerWidget {
  const VerHorasPage({super.key});

  String _hhmmFromMinutes(int minutes) {
    final value = minutes.abs();
    final hours = value ~/ 60;
    final rest = value % 60;

    return '$hours:${rest.toString().padLeft(2, '0')}';
  }

  String _duracionRegistro(HoraRegistro registro) {
    final minutes = registro.minutos;
    if (minutes == null || minutes <= 0) return '-';

    return _hhmmFromMinutes(minutes);
  }

  AsyncValue<List<Persona>> _mergeListados({
    required AsyncValue<List<Persona>> normales,
    required AsyncValue<List<Persona>> oficiales,
  }) {
    if (normales.hasError) {
      return AsyncValue.error(normales.error!, normales.stackTrace!);
    }

    if (oficiales.hasError) {
      return AsyncValue.error(oficiales.error!, oficiales.stackTrace!);
    }

    if (normales.isLoading || oficiales.isLoading) {
      return const AsyncValue.loading();
    }

    final a = normales.valueOrNull ?? <Persona>[];
    final b = oficiales.valueOrNull ?? <Persona>[];

    final map = <String, Persona>{
      for (final p in [...a, ...b]) p.key: p,
    };

    final out = map.values.toList()..sort(_comparePersona);

    return AsyncValue.data(out);
  }

  static int _comparePersona(Persona a, Persona b) {
    final apellido = a.apellido.toLowerCase().compareTo(
          b.apellido.toLowerCase(),
        );
    if (apellido != 0) return apellido;

    final nombre = a.nombre.toLowerCase().compareTo(
          b.nombre.toLowerCase(),
        );
    if (nombre != 0) return nombre;

    final dni = a.dni.compareTo(b.dni);
    if (dni != 0) return dni;

    return a.carreraId.compareTo(b.carreraId);
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

  ({int aplicados, int excedidos, Map<int, int> excedidoPorId})
      _calcParticularCupo(
    List<HoraRegistro> rows, {
    int limiteMin = VerHorasMath.limiteParticularMin,
  }) {
    final particulares = rows.where((r) => r.esParticular).toList()
      ..sort((a, b) {
        final fecha = a.fecha.compareTo(b.fecha);
        if (fecha != 0) return fecha;

        return a.id.compareTo(b.id);
      });

    var usado = 0;
    var aplicados = 0;
    var excedidos = 0;
    final excedidoPorId = <int, int>{};

    for (final registro in particulares) {
      final duracion = registro.minutos ?? 0;
      if (duracion <= 0) {
        excedidoPorId[registro.id] = 0;
        continue;
      }

      final restante = (limiteMin - usado) < 0 ? 0 : limiteMin - usado;
      final aplicado = duracion <= restante ? duracion : restante;
      final excedido = duracion - aplicado;

      usado += aplicado;
      aplicados += aplicado;
      excedidos += excedido;

      excedidoPorId[registro.id] = excedido;
    }

    return (
      aplicados: aplicados,
      excedidos: excedidos,
      excedidoPorId: excedidoPorId,
    );
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
        return PersonaPickerSheet(
          items: items,
          selectedKey: current?.key,
        );
      },
    );

    if (picked != null) {
      ref.read(selectedPersonaProvider.notifier).state = picked;
    }
  }

  Future<DateTime?> _pickPeriodo(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final current = ref.read(periodoProvider);
    final base = DateFmt.maxMonthStart(DateTime.now(), current);
    final meses = DateFmt.mesesHaciaAtras(base: base, count: 36);

    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) {
        return PeriodoPickerSheet(
          meses: meses,
          current: current,
        );
      },
    );
  }

  Future<void> _borrarRegistro(
    BuildContext context,
    WidgetRef ref,
    HoraRegistro registro,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Borrar registro'),
          content: Text(
            '¿Borrar el registro del ${DateFmt.ddmmyyyy(registro.fecha)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Borrar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final ok = await ref
          .read(borrarHoraControllerProvider.notifier)
          .borrar(registro.id);

      if (!context.mounted) return;

      if (ok) {
        AppSnackBar.success(context, 'Registro borrado');
      } else {
        AppSnackBar.error(
          context,
          'No se borró. El registro no fue encontrado.',
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      AppSnackBar.error(
        context,
        'Error borrando: ${cleanError(e)}',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(periodoProvider);

    final listadoNormal = ref.watch(listadoProvider);
    final listadoOficiales = ref.watch(listadoOficialesProvider);
    final personasAsync = _mergeListados(
      normales: listadoNormal,
      oficiales: listadoOficiales,
    );

    final persona = ref.watch(selectedPersonaProvider);
    final registrosAsync = ref.watch(registrosProvider);
    final borrarState = ref.watch(borrarHoraControllerProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          VerPeriodoHeader(
            periodo: periodo,
            onTap: () async {
              final picked = await _pickPeriodo(context, ref);
              if (picked == null) return;

              ref.read(periodoProvider.notifier).state =
                  DateFmt.monthStart(picked);
            },
          ),
          const SizedBox(height: 12),
          personasAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return const InfoBox(
                  text: 'Sin personas en el listado o sin permiso.',
                );
              }

              final selected = _resolveSelectedPersona(persona, items);

              if (selected == null) {
                return const InfoBox(
                  text: 'No hay una persona seleccionable.',
                );
              }

              _syncSelectedPersonaAfterBuild(
                context: context,
                ref: ref,
                resolved: selected,
                current: persona,
              );

              return PersonaSelectorField(
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
            error: (e, _) => InfoBox(
              text: 'Error listado: ${cleanError(e)}',
              error: true,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: registrosAsync.when(
              data: (rows) {
                final calcParticular = _calcParticularCupo(rows);

                return Column(
                  children: [
                    ResumenHorasCard(
                      persona: persona,
                      rows: rows,
                      calcParticular: calcParticular,
                      hhmmFromMinutes: _hhmmFromMinutes,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: RegistrosList(
                        rows: rows,
                        borrarLoading: borrarState.isLoading,
                        calcParticular: calcParticular,
                        duracionRegistro: _duracionRegistro,
                        hhmmFromMinutes: _hhmmFromMinutes,
                        onDelete: (registro) {
                          _borrarRegistro(context, ref, registro);
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: InfoBox(
                  text: 'Error registros: ${cleanError(e)}',
                  error: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

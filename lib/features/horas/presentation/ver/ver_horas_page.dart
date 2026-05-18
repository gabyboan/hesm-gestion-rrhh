import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_fmt.dart';
import '../../application/horas_providers.dart';
import '../../domain/hora_registro.dart';
import '../../domain/persona.dart';

class VerHorasPage extends ConsumerWidget {
  const VerHorasPage({super.key});

  // ===== Helpers format =====

  String _hhmmFromMinutes(int minutes) {
    final m = minutes.abs();
    final h = m ~/ 60;
    final r = m % 60;
    return '${h.toString()}:${r.toString().padLeft(2, '0')}';
  }

  String _duracionRegistro(HoraRegistro r) {
    final min = r.minutos;
    if (min == null) return '-';
    return _hhmmFromMinutes(min);
  }

  bool _matchPersona(Persona p, String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return true;

    final dni = p.dni.toString();
    final ape = p.apellido.toLowerCase();
    final nom = p.nombre.toLowerCase();
    final carrera = p.carrera.toLowerCase();

    return dni.contains(s) ||
        ape.contains(s) ||
        nom.contains(s) ||
        carrera.contains(s) ||
        p.label.toLowerCase().contains(s);
  }

  /// ✅ Recalcula aplicado/excedido de PARTICULARES (coherente con límite 180)
  /// Devuelve:
  /// - aplicadosTotal
  /// - excedidosTotal
  /// - mapExcedidoPorRegistroId (para mostrar en el listado)
  ({int aplicados, int excedidos, Map<int, int> excById}) _calcParticularCupo(
    List<HoraRegistro> rows, {
    int limiteMin = 180,
  }) {
    final parts = rows
        .where((r) => (r.tipo ?? '').toUpperCase() == 'PARTICULAR')
        .toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    var usado = 0;
    var aplicados = 0;
    var excedidos = 0;
    final excById = <int, int>{};

    for (final r in parts) {
      final dur = (r.minutos ?? 0);
      if (dur <= 0) {
        excById[r.id] = 0;
        continue;
      }

      final restante = (limiteMin - usado).clamp(0, limiteMin);
      final aplicado = dur <= restante ? dur : restante;
      final exc = dur - aplicado;

      aplicados += aplicado;
      excedidos += exc;
      usado += aplicado;

      excById[r.id] = exc;
    }

    return (aplicados: aplicados, excedidos: excedidos, excById: excById);
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
                                    subtitle: Text(
                                      'DNI: ${p.dni} • Carrera: ${p.carreraId} • ${p.carrera}',
                                    ),
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
      ref.invalidate(registrosProvider);
    }
  }

  Future<DateTime?> _pickPeriodoDialog(
      BuildContext context, WidgetRef ref) async {
    final current = ref.read(periodoProvider);
    final base = DateFmt.maxMonthStart(DateTime.now(), current);
    final meses = DateFmt.mesesHaciaAtras(base: base, count: 36);

    return showDialog<DateTime>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Seleccionar periodo'),
        contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
        content: SizedBox(
          width: 420,
          height: 420,
          child: ListView.separated(
            itemCount: meses.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final m = meses[i];
              final selected =
                  (m.year == current.year && m.month == current.month);

              return ListTile(
                title: Text(DateFmt.mes(m)),
                subtitle: Text(DateFmt.anio(m)),
                trailing: selected ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, m),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(periodoProvider);

    final listadoNormal = ref.watch(listadoProvider);
    final listadoOficiales = ref.watch(listadoOficialesProvider);

    final personaSel = ref.watch(selectedPersonaProvider);
    final registrosAsync = ref.watch(registrosProvider);

    final borrarState = ref.watch(borrarHoraControllerProvider);

    void snack(String msg, {bool err = false}) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: err ? Colors.red : null),
      );
    }

    Future<void> borrar(int id) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Borrar'),
          content: const Text('¿Borrar este registro?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Borrar'),
            ),
          ],
        ),
      );

      if (ok != true) return;

      try {
        final res =
            await ref.read(borrarHoraControllerProvider.notifier).borrar(id);
        if (res) {
          snack('Borrado');
          ref.invalidate(registrosProvider);
        } else {
          snack('No se borró (no encontrado)', err: true);
        }
      } catch (e) {
        snack('Error borrando: $e', err: true);
      }
    }

    Widget headerPeriodo() {
      return Center(
        child: InkWell(
          onTap: () async {
            final picked = await _pickPeriodoDialog(context, ref);
            if (picked == null) return;

            ref.read(periodoProvider.notifier).state =
                DateFmt.monthStart(picked);
            ref.invalidate(registrosProvider);
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFmt.mes(periodo),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFmt.anio(periodo),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.expand_more),
              ],
            ),
          ),
        ),
      );
    }

    AsyncValue<List<Persona>> mergedListado() {
      return listadoNormal.when(
        data: (a) => listadoOficiales.when(
          data: (b) {
            final map = <String, Persona>{};
            for (final p in a) {
              map[p.key] = p;
            }
            for (final p in b) {
              map[p.key] = p;
            }
            final out = map.values.toList()
              ..sort((x, y) {
                final c = x.apellido
                    .toLowerCase()
                    .compareTo(y.apellido.toLowerCase());
                if (c != 0) return c;
                final n =
                    x.nombre.toLowerCase().compareTo(y.nombre.toLowerCase());
                if (n != 0) return n;
                final d = x.dni.compareTo(y.dni);
                if (d != 0) return d;
                return x.carreraId.compareTo(y.carreraId);
              });
            return AsyncValue.data(out);
          },
          loading: () => const AsyncValue.loading(),
          error: (e, st) => AsyncValue.error(e, st),
        ),
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    }

    Widget selectorPersona(List<Persona> items) {
      Persona selected;
      if (personaSel == null) {
        selected = items.first;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(selectedPersonaProvider.notifier).state = selected;
          ref.invalidate(registrosProvider);
        });
      } else {
        final idx = items.indexWhere((p) => p.key == personaSel.key);
        if (idx == -1) {
          selected = items.first;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(selectedPersonaProvider.notifier).state = selected;
            ref.invalidate(registrosProvider);
          });
        } else {
          selected = items[idx];
        }
      }

      return InkWell(
        onTap: () => _pickPersonaModal(context, ref, items),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Empleado',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.expand_more),
          ),
          child: Text(selected.label),
        ),
      );
    }

    Widget resumenEnRecuadro({
      required Persona? persona,
      required List<HoraRegistro> rows,
    }) {
      final esCarrera2 = (persona?.carreraId == 2);

      const oficialLine = 'Horas oficiales: sin límite';

      if (esCarrera2) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.black.withOpacity(0.10)),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      oficialLine,
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // ✅ PARTICULAR: límite mensual fijo 180 min
      const limiteParticular = 180;

      // ✅ recalculado (no confiamos en DB)
      final calc = _calcParticularCupo(rows, limiteMin: limiteParticular);
      final aplicadosParticular = calc.aplicados;
      final excedidosParticular = calc.excedidos;

      bool usoEnfermedad = false;
      for (final r in rows) {
        final t = (r.tipo ?? '').toUpperCase();
        if (t == 'ENFERMEDAD') {
          usoEnfermedad = true;
          break;
        }
      }

      final restantes =
          (limiteParticular - aplicadosParticular).clamp(0, limiteParticular);

      Color colorPart;
      String partLine;

      if (excedidosParticular > 0) {
        colorPart = Colors.red;
        partLine =
            'Horas particulares disponibles: Excedido ${_hhmmFromMinutes(excedidosParticular)}';
      } else if (restantes == 0) {
        colorPart = Colors.orange;
        partLine = 'Horas particulares disponibles: No disponible';
      } else {
        colorPart = Colors.green;
        partLine =
            'Horas particulares disponibles: ${_hhmmFromMinutes(restantes)}';
      }

      final colorEnf = usoEnfermedad ? Colors.orange : Colors.green;
      final enfLine =
          'Horas por enfermedad: ${usoEnfermedad ? 'No disponible' : 'Disponible'}';

      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.black.withOpacity(0.10)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partLine,
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: colorPart),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    enfLine,
                    style:
                        TextStyle(fontWeight: FontWeight.w800, color: colorEnf),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    oficialLine,
                    style: TextStyle(
                        color: Colors.black54, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget listaRegistros(List<HoraRegistro> rows) {
      if (rows.isEmpty) {
        return const Center(
          child: Text('Sin registros para este empleado en el periodo'),
        );
      }

      // ✅ recalculo para mostrar excedido coherente en la lista
      const limiteParticular = 180;
      final calc = _calcParticularCupo(rows, limiteMin: limiteParticular);
      final excById = calc.excById;

      return ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final r = rows[i];
          final tipo = (r.tipo ?? '').toUpperCase();
          final dur = _duracionRegistro(r);

          String extra = '';
          if (tipo == 'PARTICULAR') {
            final exc = excById[r.id] ?? 0;
            if (exc > 0) {
              extra = ' • Excedido: ${_hhmmFromMinutes(exc)}';
            }
          } else {
            // si querés conservar excedido en otros tipos, dejalo:
            if (r.excedido == true && (r.minutosExcedidos ?? 0) > 0) {
              extra =
                  ' • Excedido: ${_hhmmFromMinutes(r.minutosExcedidos ?? 0)}';
            }
          }

          return ListTile(
            title: Text('${DateFmt.ddmmyyyy(r.fecha)} • $tipo'),
            subtitle: Text('Duración: $dur$extra'),
            trailing: IconButton(
              tooltip: 'Borrar (solo ADM)',
              onPressed: borrarState.isLoading ? null : () => borrar(r.id),
              icon: const Icon(Icons.delete_outline),
            ),
          );
        },
      );
    }

    final mergedAsync = mergedListado();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          headerPeriodo(),
          const SizedBox(height: 12),
          mergedAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return const Text(
                    'Sin personas en el listado (o sin permiso).');
              }
              return selectorPersona(items);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error listado: $e'),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: registrosAsync.when(
              data: (rows) {
                return Column(
                  children: [
                    resumenEnRecuadro(persona: personaSel, rows: rows),
                    const SizedBox(height: 12),
                    Expanded(child: listaRegistros(rows)),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error registros: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

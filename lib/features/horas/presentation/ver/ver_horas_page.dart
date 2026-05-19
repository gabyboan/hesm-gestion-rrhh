// lib/features/horas/presentation/ver/ver_horas_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_fmt.dart';
import '../../application/horas_providers.dart';
import '../../domain/hora_registro.dart';
import '../../domain/persona.dart';

class VerHorasPage extends ConsumerWidget {
  const VerHorasPage({super.key});

  static const int _limiteParticularMin = 180;

  String _cleanError(Object e) {
    final msg = e.toString().trim();
    if (msg.isEmpty) return 'error desconocido';

    return msg.replaceFirst('Exception: ', '');
  }

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
    int limiteMin = _limiteParticularMin,
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
        return _PeriodoPickerSheet(
          meses: meses,
          current: current,
        );
      },
    );
  }

  void _showSnack(
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
        _showSnack(context, 'Registro borrado');
      } else {
        _showSnack(context, 'No se borró. El registro no fue encontrado.',
            error: true);
      }
    } catch (e) {
      if (!context.mounted) return;

      _showSnack(
        context,
        'Error borrando: ${_cleanError(e)}',
        error: true,
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
          _PeriodoHeader(
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
              text: 'Error listado: ${_cleanError(e)}',
              error: true,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: registrosAsync.when(
              data: (rows) {
                return Column(
                  children: [
                    _ResumenHorasCard(
                      persona: persona,
                      rows: rows,
                      calcParticular: _calcParticularCupo(rows),
                      hhmmFromMinutes: _hhmmFromMinutes,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _RegistrosList(
                        rows: rows,
                        borrarLoading: borrarState.isLoading,
                        calcParticular: _calcParticularCupo(rows),
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
                child: _InfoBox(
                  text: 'Error registros: ${_cleanError(e)}',
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

class _PeriodoHeader extends StatelessWidget {
  final DateTime periodo;
  final VoidCallback onTap;

  const _PeriodoHeader({
    required this.periodo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 6,
            horizontal: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFmt.mes(periodo),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                DateFmt.anio(periodo),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.expand_more),
            ],
          ),
        ),
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
          labelText: 'Empleado',
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

class _ResumenHorasCard extends StatelessWidget {
  final Persona? persona;
  final List<HoraRegistro> rows;
  final ({
    int aplicados,
    int excedidos,
    Map<int, int> excedidoPorId
  }) calcParticular;
  final String Function(int minutes) hhmmFromMinutes;

  const _ResumenHorasCard({
    required this.persona,
    required this.rows,
    required this.calcParticular,
    required this.hhmmFromMinutes,
  });

  static const _oficialLine = 'Horas oficiales: sin límite';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final esCarreraOficial = persona?.carreraId == 2;

    if (esCarreraOficial) {
      return _SummaryContainer(
        children: [
          Text(
            _oficialLine,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.primary,
            ),
          ),
        ],
      );
    }

    final aplicadosParticular = calcParticular.aplicados;
    final excedidosParticular = calcParticular.excedidos;
    final usoEnfermedad = rows.any((r) => r.esEnfermedad);

    final restantes = (_VerHorasMath.limiteParticularMin - aplicadosParticular);
    final disponibles = restantes < 0 ? 0 : restantes;

    late final Color colorParticular;
    late final String particularLine;

    if (excedidosParticular > 0) {
      colorParticular = cs.error;
      particularLine =
          'Horas particulares disponibles: Excedido ${hhmmFromMinutes(excedidosParticular)}';
    } else if (disponibles == 0) {
      colorParticular = Colors.orange.shade700;
      particularLine = 'Horas particulares disponibles: No disponible';
    } else {
      colorParticular = Colors.green.shade700;
      particularLine =
          'Horas particulares disponibles: ${hhmmFromMinutes(disponibles)}';
    }

    final colorEnfermedad =
        usoEnfermedad ? Colors.orange.shade700 : Colors.green.shade700;
    final enfermedadLine =
        'Horas por enfermedad: ${usoEnfermedad ? 'No disponible' : 'Disponible'}';

    return _SummaryContainer(
      children: [
        Text(
          particularLine,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: colorParticular,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          enfermedadLine,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: colorEnfermedad,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _oficialLine,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SummaryContainer extends StatelessWidget {
  final List<Widget> children;

  const _SummaryContainer({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cs.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class _RegistrosList extends StatelessWidget {
  final List<HoraRegistro> rows;
  final bool borrarLoading;
  final ({
    int aplicados,
    int excedidos,
    Map<int, int> excedidoPorId
  }) calcParticular;
  final String Function(HoraRegistro registro) duracionRegistro;
  final String Function(int minutes) hhmmFromMinutes;
  final ValueChanged<HoraRegistro> onDelete;

  const _RegistrosList({
    required this.rows,
    required this.borrarLoading,
    required this.calcParticular,
    required this.duracionRegistro,
    required this.hhmmFromMinutes,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Text('Sin registros para este empleado en el período'),
      );
    }

    final ordered = rows.toList()
      ..sort((a, b) {
        final fecha = b.fecha.compareTo(a.fecha);
        if (fecha != 0) return fecha;

        return b.id.compareTo(a.id);
      });

    return ListView.separated(
      itemCount: ordered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final registro = ordered[index];

        return _RegistroTile(
          registro: registro,
          borrarLoading: borrarLoading,
          duracion: duracionRegistro(registro),
          extra: _extraForRegistro(registro),
          onDelete: () => onDelete(registro),
        );
      },
    );
  }

  String _extraForRegistro(HoraRegistro registro) {
    if (registro.esParticular) {
      final excedido = calcParticular.excedidoPorId[registro.id] ?? 0;
      if (excedido > 0) {
        return ' • Excedido: ${hhmmFromMinutes(excedido)}';
      }

      return '';
    }

    if (registro.tieneExcedente) {
      return ' • Excedido: ${hhmmFromMinutes(registro.minutosExcedidos)}';
    }

    return '';
  }
}

class _RegistroTile extends StatelessWidget {
  final HoraRegistro registro;
  final bool borrarLoading;
  final String duracion;
  final String extra;
  final VoidCallback onDelete;

  const _RegistroTile({
    required this.registro,
    required this.borrarLoading,
    required this.duracion,
    required this.extra,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tipo = registro.tipoNormalizado;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text('${DateFmt.ddmmyyyy(registro.fecha)} • $tipo'),
      subtitle: Text('Duración: $duracion$extra'),
      trailing: IconButton(
        tooltip: 'Borrar',
        onPressed: borrarLoading ? null : onDelete,
        icon: const Icon(Icons.delete_outline),
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

  bool _matches(Persona persona, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    final values = [
      persona.dni.toString(),
      persona.apellido,
      persona.nombre,
      persona.carrera,
      persona.carreraId.toString(),
      persona.label,
      persona.key,
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
                          final persona = filtered[index];
                          final selected = persona.key == widget.selectedKey;

                          return ListTile(
                            title:
                                Text('${persona.apellido}, ${persona.nombre}'),
                            subtitle: Text(
                              'DNI: ${persona.dni} · Carrera: ${persona.carreraId} · ${persona.carrera}',
                            ),
                            trailing: selected
                                ? const Icon(Icons.check_circle)
                                : null,
                            onTap: () => Navigator.of(context).pop(persona),
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

class _PeriodoPickerSheet extends StatelessWidget {
  final List<DateTime> meses;
  final DateTime current;

  const _PeriodoPickerSheet({
    required this.meses,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Column(
          children: [
            const Text(
              'Seleccionar período',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: meses.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final mes = meses[index];
                  final selected =
                      mes.year == current.year && mes.month == current.month;

                  return ListTile(
                    title: Text(DateFmt.mes(mes)),
                    subtitle: Text(DateFmt.anio(mes)),
                    trailing: selected ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.of(context).pop(mes),
                  );
                },
              ),
            ),
          ],
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

class _VerHorasMath {
  static const int limiteParticularMin = 180;
}

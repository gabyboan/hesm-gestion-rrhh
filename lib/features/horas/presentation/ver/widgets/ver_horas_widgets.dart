import 'package:flutter/material.dart';

import '../../../../../core/utils/date_fmt.dart';
import '../../../domain/hora_registro.dart';
import '../../../domain/persona.dart';

class VerHorasMath {
  static const int limiteParticularMin = 180;
}

class VerPeriodoHeader extends StatelessWidget {
  final DateTime periodo;
  final VoidCallback onTap;

  const VerPeriodoHeader({
    super.key,
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

class PersonaSelectorField extends StatelessWidget {
  final Persona persona;
  final VoidCallback onTap;

  const PersonaSelectorField({
    super.key,
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

class ResumenHorasCard extends StatelessWidget {
  final Persona? persona;
  final List<HoraRegistro> rows;
  final ({
    int aplicados,
    int excedidos,
    Map<int, int> excedidoPorId
  }) calcParticular;
  final String Function(int minutes) hhmmFromMinutes;

  const ResumenHorasCard({
    super.key,
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

    final restantes = VerHorasMath.limiteParticularMin - aplicadosParticular;
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

class RegistrosList extends StatelessWidget {
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

  const RegistrosList({
    super.key,
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
        return ' - Excedido: ${hhmmFromMinutes(excedido)}';
      }

      return '';
    }

    if (registro.tieneExcedente) {
      return ' - Excedido: ${hhmmFromMinutes(registro.minutosExcedidos)}';
    }

    return '';
  }
}

class PersonaPickerSheet extends StatefulWidget {
  final List<Persona> items;
  final String? selectedKey;

  const PersonaPickerSheet({
    super.key,
    required this.items,
    required this.selectedKey,
  });

  @override
  State<PersonaPickerSheet> createState() => _PersonaPickerSheetState();
}

class PeriodoPickerSheet extends StatelessWidget {
  final List<DateTime> meses;
  final DateTime current;

  const PeriodoPickerSheet({
    super.key,
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

class InfoBox extends StatelessWidget {
  final String text;
  final bool error;

  const InfoBox({
    super.key,
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
      title: Text('${DateFmt.ddmmyyyy(registro.fecha)} - $tipo'),
      subtitle: Text('Duración: $duracion$extra'),
      trailing: IconButton(
        tooltip: 'Borrar',
        onPressed: borrarLoading ? null : onDelete,
        icon: const Icon(Icons.delete_outline),
      ),
    );
  }
}

class _PersonaPickerSheetState extends State<PersonaPickerSheet> {
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
                              'DNI: ${persona.dni} - Carrera: ${persona.carreraId} - ${persona.carrera}',
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

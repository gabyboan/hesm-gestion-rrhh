import 'package:flutter/material.dart';

import '../../../../../core/utils/date_fmt.dart';
import '../../../../../core/utils/search_query.dart';
import '../../../../../core/widgets/app_search_field.dart';
import '../../../domain/cupo_particular.dart';
import '../../../domain/persona.dart';
import '../../../domain/tipo_hora.dart';
import 'pick_duracion_30.dart';

class CargarCupoParticularBox extends StatelessWidget {
  final DateTime periodo;
  final CupoParticular cupo;
  final int? minutosSeleccionados;

  const CargarCupoParticularBox({
    super.key,
    required this.periodo,
    required this.cupo,
    required this.minutosSeleccionados,
  });

  String _duracion(int minutos) =>
      '${minutos ~/ 60}:${(minutos % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final excedido = cupo.excedidoConCarga(minutosSeleccionados ?? 0);
    final cs = Theme.of(context).colorScheme;
    final color = excedido > 0 ? cs.error : cs.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: excedido > 0 ? cs.errorContainer : cs.surfaceContainerHighest,
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(excedido > 0 ? Icons.warning_amber_rounded : Icons.schedule,
              color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Horas particulares · ${DateFmt.mesNombre(periodo)} ${periodo.year}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                    'Cargadas: ${_duracion(cupo.total)} h · Cupo mensual: 3:00 h'),
                if (minutosSeleccionados != null)
                  Text(
                      'Total con esta carga: ${_duracion(cupo.total + minutosSeleccionados!)} h'),
                if (excedido > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Límite mensual excedido en ${_duracion(excedido)} h. Podés guardar y seguir cargando; se contabiliza toda la duración.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ] else
                  Text('Disponibles: ${_duracion(cupo.disponibles)} h'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CargarPersonaSelectorField extends StatelessWidget {
  final Persona persona;
  final VoidCallback onTap;

  const CargarPersonaSelectorField({
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

class CargarDateSelectorField extends StatelessWidget {
  final DateTime fecha;
  final VoidCallback onTap;

  const CargarDateSelectorField({
    super.key,
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

class TipoHoraSelector extends StatelessWidget {
  final TipoHora selected;
  final ValueChanged<TipoHora> onChanged;

  const TipoHoraSelector({
    super.key,
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

class MinutosParticularesChips extends StatelessWidget {
  final int? selected;
  final ValueChanged<int> onSelected;

  const MinutosParticularesChips({
    super.key,
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

class DuracionOficialField extends StatelessWidget {
  final int? minutos;
  final VoidCallback onTap;

  const DuracionOficialField({
    super.key,
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

class CargarPersonaPickerSheet extends StatefulWidget {
  final List<Persona> items;
  final String? selectedKey;

  const CargarPersonaPickerSheet({
    super.key,
    required this.items,
    required this.selectedKey,
  });

  @override
  State<CargarPersonaPickerSheet> createState() =>
      _CargarPersonaPickerSheetState();
}

class CargarInfoBox extends StatelessWidget {
  final String text;
  final bool error;

  const CargarInfoBox({
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

class _CargarPersonaPickerSheetState extends State<CargarPersonaPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final query = SearchQuery(_search);
    final filtered = widget.items
        .where((p) => query.matches([
              p.dni,
              p.apellido,
              p.nombre,
              p.carrera,
              p.carreraId,
            ]))
        .toList();

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
              AppSearchField(
                labelText: 'Buscar por DNI, apellido, nombre o carrera',
                autofocus: true,
                debounce: Duration.zero,
                onChanged: (value) => setState(() => _search = value),
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

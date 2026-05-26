import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/informe_providers.dart';

class InformeFilterBar extends ConsumerWidget {
  const InformeFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtros = ref.watch(informeFiltrosProvider);

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _chip(ref, filtros, InformeFiltro.soloConUso, 'Solo con uso'),
          _chip(ref, filtros, InformeFiltro.particulares, 'Particulares'),
          _chip(ref, filtros, InformeFiltro.enfermedad, 'Enfermedad'),
          _chip(ref, filtros, InformeFiltro.oficiales, 'Oficiales'),
          _chip(ref, filtros, InformeFiltro.excedidos, 'Excedidos'),
        ],
      ),
    );
  }

  Widget _chip(
    WidgetRef ref,
    Set<InformeFiltro> filtros,
    InformeFiltro filtro,
    String label,
  ) {
    final selected = filtros.contains(filtro);

    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: (value) {
        final next = {...filtros};

        if (value) {
          next.add(filtro);
        } else {
          next.remove(filtro);
        }

        ref.read(informeFiltrosProvider.notifier).state = next;
      },
    );
  }
}

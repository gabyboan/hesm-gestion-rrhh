import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/export/export_informe_xlsx.dart';
import '../../../../core/utils/date_fmt.dart';
import '../../application/horas_providers.dart';
import '../../application/informe_providers.dart';

class InformePage extends ConsumerWidget {
  const InformePage({super.key});

  // ===== Helpers formato =====

  String _hhmm(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return "${m}'";
    return "${h}:${m.toString().padLeft(2, '0')}";
  }

  String _ddmm(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}";

  String _resumenParticulares(Map<DateTime, int> porDia) {
    if (porDia.isEmpty) return '';
    final dias = porDia.keys.toList()..sort();
    return dias.map((d) => "${_hhmm(porDia[d]!)} ${_ddmm(d)}").join(" | ");
  }

  String _resumenEnfermedad(Map<DateTime, int> porDia) {
    if (porDia.isEmpty) return '';
    final dias = porDia.keys.toList()..sort();
    return dias.map(_ddmm).join(" | ");
  }

  String _cleanError(Object e) {
    final msg = e.toString().trim();
    if (msg.isEmpty) return 'error desconocido';

    return msg.replaceFirst('Exception: ', '');
  }

  // ===== Selector de período (mes) =====

  Future<DateTime?> _pickPeriodoDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
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
                  m.year == current.year && m.month == current.month;

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

  Widget _headerPeriodo(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(periodoProvider);

    return Center(
      child: InkWell(
        onTap: () async {
          final picked = await _pickPeriodoDialog(context, ref);
          if (picked == null) return;

          ref.read(periodoProvider.notifier).state = DateFmt.monthStart(picked);

          ref.invalidate(registrosPeriodoProvider);
          ref.invalidate(informeRowsProvider);
        },
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

  Future<void> _exportExcelMes(BuildContext context, WidgetRef ref) async {
    final picked = await _pickPeriodoDialog(context, ref);
    if (picked == null) return;

    final periodo = DateFmt.monthStart(picked);

    try {
      ref.read(periodoProvider.notifier).state = periodo;

      ref.invalidate(registrosPeriodoProvider);
      ref.invalidate(informeRowsExportProvider);

      final rows = await ref.read(informeRowsExportProvider.future);

      final exported = await exportInformeXlsx(
        periodo: periodo,
        rows: rows,
      );

      if (!context.mounted) return;

      if (exported) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Excel exportado'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('No se pudo exportar: ${_cleanError(e)}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    }
  }

  // ===== UI celdas =====

  Widget _cell(
    String text, {
    required double width,
    bool bold = false,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            fontSize: 13.5,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _row3cols({
    required String enf,
    required String nombre,
    required String part,
    required String trailingSmall,
    bool header = false,
  }) {
    return LayoutBuilder(
      builder: (context, c) {
        final cs = Theme.of(context).colorScheme;

        const wEnf = 220.0;
        const wNombre = 320.0;
        final wPart = (c.maxWidth - wEnf - wNombre).clamp(200.0, 20000.0);

        return Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: cs.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              _cell(enf, width: wEnf, bold: header),
              _cell(nombre, width: wNombre, bold: true),
              SizedBox(
                width: wPart,
                child: Row(
                  children: [
                    Expanded(
                      child: _cell(
                        part,
                        width: wPart,
                        bold: header,
                      ),
                    ),
                    if (trailingSmall.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text(
                          trailingSmall,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===== UI =====

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(informeRowsProvider);
    final filtros = ref.watch(informeFiltrosProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => _exportExcelMes(context, ref),
              icon: const Icon(Icons.download),
              label: const Text('Exportar Excel'),
            ),
          ),
          const SizedBox(height: 8),
          _headerPeriodo(context, ref),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(ref, filtros, InformeFiltro.soloConUso, 'Solo con uso'),
                _chip(
                  ref,
                  filtros,
                  InformeFiltro.particulares,
                  'Particulares',
                ),
                _chip(ref, filtros, InformeFiltro.enfermedad, 'Enfermedad'),
                _chip(ref, filtros, InformeFiltro.oficiales, 'Oficiales'),
                _chip(ref, filtros, InformeFiltro.excedidos, 'Excedidos'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _row3cols(
            enf: 'Enfermedad',
            nombre: 'Apellido, Nombre',
            part: 'Particulares',
            trailingSmall: '',
            header: true,
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => Center(
                child: Text('Error: ${_cleanError(e)}'),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return const Center(
                    child: Text('Sin resultados'),
                  );
                }

                return ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    final p = r.persona;

                    final enfTxt = _resumenEnfermedad(r.enfermedadPorDia);
                    final partTxt = _resumenParticulares(
                      r.particularesPorDia,
                    );

                    return _row3cols(
                      enf: enfTxt,
                      nombre: '${p.apellido}, ${p.nombre}',
                      part: partTxt,
                      trailingSmall: 'DNI ${p.dni} • C${p.carreraId}',
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    WidgetRef ref,
    Set<InformeFiltro> filtros,
    InformeFiltro f,
    String label,
  ) {
    final selected = filtros.contains(f);

    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: (v) {
        final next = {...filtros};

        if (v) {
          next.add(f);
        } else {
          next.remove(f);
        }

        ref.read(informeFiltrosProvider.notifier).state = next;
      },
    );
  }
}

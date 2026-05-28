import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/export/export_informe_xlsx.dart';
import '../../../../core/ui/app_snackbar.dart';
import '../../../../core/utils/date_fmt.dart';
import '../../../../core/utils/error_text.dart';
import '../../application/horas_providers.dart';
import '../../application/informe_providers.dart';
import 'widgets/informe_filter_bar.dart';
import 'widgets/informe_periodo_dialog.dart';
import 'widgets/informe_periodo_header.dart';
import 'widgets/informe_rows_table.dart';

class InformePage extends ConsumerWidget {
  const InformePage({super.key});

  Future<DateTime?> _pickPeriodoDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final current = ref.read(periodoProvider);
    Set<DateTime>? periodosConRegistros;
    try {
      periodosConRegistros =
          await ref.read(periodosConRegistrosProvider.future);
    } catch (_) {
      periodosConRegistros = null;
    }
    if (!context.mounted) return null;

    if (periodosConRegistros != null && periodosConRegistros.isEmpty) {
      AppSnackBar.error(context, 'No hay meses con horas cargadas');
      return null;
    }

    return showInformePeriodoDialog(
      context: context,
      current: current,
      periodosConRegistros: periodosConRegistros,
    );
  }

  Future<void> _changePeriodo(BuildContext context, WidgetRef ref) async {
    try {
      final picked = await _pickPeriodoDialog(context, ref);
      if (picked == null) return;
      if (!context.mounted) return;

      final periodo = DateFmt.monthStart(picked);
      ref.read(periodoProvider.notifier).state = periodo;

      ref.invalidate(registrosPeriodoProvider);
      ref.invalidate(informeRowsProvider);
    } catch (e) {
      if (!context.mounted) return;

      AppSnackBar.error(
        context,
        'No se pudo abrir el selector: ${cleanError(e)}',
      );
    }
  }

  Future<void> _exportExcelMes(BuildContext context, WidgetRef ref) async {
    try {
      final picked = await _pickPeriodoDialog(context, ref);
      if (picked == null) return;
      if (!context.mounted) return;

      final periodo = DateFmt.monthStart(picked);

      ref.read(periodoProvider.notifier).state = periodo;

      ref.invalidate(registrosPeriodoProvider);
      ref.invalidate(informeRowsExportProvider);

      final rows = await ref.read(informeRowsExportProvider.future);
      if (!rows.any((row) => row.tieneUso)) {
        if (!context.mounted) return;

        AppSnackBar.error(context, 'No hay horas cargadas para exportar');
        return;
      }

      final exported = await exportInformeXlsx(
        periodo: periodo,
        rows: rows,
      );

      if (!context.mounted) return;

      if (exported) {
        AppSnackBar.success(context, 'Excel exportado');
      }
    } catch (e) {
      if (!context.mounted) return;

      AppSnackBar.error(context, 'No se pudo exportar: ${cleanError(e)}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(informeRowsProvider);
    final periodo = ref.watch(periodoProvider);

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
          InformePeriodoHeader(
            periodo: periodo,
            onTap: () => _changePeriodo(context, ref),
          ),
          const SizedBox(height: 12),
          const InformeFilterBar(),
          const SizedBox(height: 12),
          InformeRowsTable(rows: rows),
        ],
      ),
    );
  }
}

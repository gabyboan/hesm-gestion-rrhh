import 'package:flutter/material.dart';

import '../../../../../core/utils/date_fmt.dart';

Future<DateTime?> showInformePeriodoDialog({
  required BuildContext context,
  required DateTime current,
  required Set<DateTime>? periodosConRegistros,
}) {
  final periodosKeys = periodosConRegistros == null
      ? null
      : {
          for (final periodo in periodosConRegistros) DateFmt.monthKey(periodo),
        };

  var base = DateFmt.periodoActual();
  for (final periodo in periodosConRegistros ?? const <DateTime>{}) {
    base = DateFmt.maxMonthStart(base, periodo);
  }

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
            final mes = meses[i];
            final selected =
                mes.year == current.year && mes.month == current.month;
            final enabled = periodosKeys == null ||
                periodosKeys.contains(DateFmt.monthKey(mes));

            return ListTile(
              title: Text(DateFmt.mes(mes)),
              subtitle: Text(enabled ? DateFmt.anio(mes) : 'Sin registros'),
              trailing: selected ? const Icon(Icons.check) : null,
              enabled: enabled,
              onTap: enabled ? () => Navigator.pop(context, mes) : null,
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

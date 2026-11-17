import 'package:flutter/material.dart';

import '../../../core/utils/date_fmt.dart';
import '../domain/conflicto_parte_medico.dart';

Future<T?> guardarParteSinConflictos<T>({
  required BuildContext context,
  required Future<T> Function() guardar,
}) async {
  try {
    return await guardar();
  } on ConflictosPartesMedicos catch (error) {
    if (!context.mounted) return null;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(error.conflictos.any((c) => c.duplicado)
            ? 'Parte médico duplicado'
            : 'Partes médicos superpuestos'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'No se puede guardar el parte. Esta persona ya tiene partes médicos que coinciden con la fecha o el período que intentás registrar.'),
                for (final conflicto in error.conflictos) ...[
                  const SizedBox(height: 12),
                  Text('Parte N.º ${conflicto.id} · ${conflicto.tipo.label}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                      'Del ${DateFmt.ddmmyyyy(conflicto.desde)} al ${DateFmt.ddmmyyyy(conflicto.hasta)}'),
                  Text(conflicto.duplicado
                      ? 'Duplicado'
                      : 'Fechas superpuestas'),
                  if (conflicto.version == 0)
                    const Text('Pendiente de devolución'),
                ],
                const SizedBox(height: 16),
                const Text(
                    'Revisá los partes existentes y las fechas antes de volver a cargar.'),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
              autofocus: true,
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Entendido')),
        ],
      ),
    );
    return null;
  }
}

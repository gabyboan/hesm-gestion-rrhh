import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/session_cache_provider.dart';
import '../../../core/ui/app_snackbar.dart';
import '../../../core/utils/date_fmt.dart';
import '../../../core/utils/error_text.dart';
import '../../ficha/application/ficha_providers.dart';
import '../application/licencias_providers.dart';
import '../domain/licencia.dart';
import 'licencia_dialog.dart';

void _actualizarLicencias(WidgetRef ref) {
  ref.read(sessionDataCacheProvider).invalidate('licencias');
  ref.invalidate(licenciasRegistrosProvider);
  ref.invalidate(fichaLicenciasProvider);
  ref.invalidate(fichaLicenciasAcumuladasProvider);
}

Future<void> mostrarFormularioLicencia(BuildContext context, WidgetRef ref,
    {LicenciaRegistro? registro}) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => LicenciaDialog(registro: registro),
  );
  if (saved != true || !context.mounted) return;
  _actualizarLicencias(ref);
  AppSnackBar.success(
      context, registro == null ? 'Licencia guardada' : 'Licencia modificada');
}

Future<void> borrarLicencia(
    BuildContext context, WidgetRef ref, LicenciaRegistro row) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Borrar licencia'),
      content: Text('¿Borrar ${row.etiqueta} de ${row.nombre}, del '
          '${DateFmt.ddmmyyyy(row.desde)} al ${DateFmt.ddmmyyyy(row.hasta)}?'
          '\n\nDejará de sumar días y de aparecer en la planilla. '
          'Se conservará como anulada en el historial.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    if (!await ref.read(licenciasRepoProvider).anular(row.id)) {
      throw StateError(
          'La licencia ya no está disponible. Actualizá el listado.');
    }
    if (!context.mounted) return;
    _actualizarLicencias(ref);
    AppSnackBar.success(context, 'Licencia borrada');
  } catch (e) {
    if (context.mounted) AppSnackBar.error(context, cleanError(e));
  }
}

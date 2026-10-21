import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_fmt.dart';
import '../../../core/utils/error_text.dart';
import '../application/cola_impresion_provider.dart';
import '../data/parte_medico_printer.dart';
import '../domain/parte_medico.dart';

class ColaImpresionDialog extends ConsumerStatefulWidget {
  const ColaImpresionDialog({super.key});

  @override
  ConsumerState<ColaImpresionDialog> createState() =>
      _ColaImpresionDialogState();
}

class _ColaImpresionDialogState extends ConsumerState<ColaImpresionDialog> {
  bool _imprimiendo = false;
  String? _mensaje;

  Future<void> _imprimir(List<ParteMedico> partes) async {
    if (_imprimiendo || partes.isEmpty) return;
    setState(() {
      _imprimiendo = true;
      _mensaje = null;
    });
    try {
      final ok = await ParteMedicoPrinter.imprimirTodos(partes);
      if (!mounted) return;
      if (ok) {
        ref
            .read(colaImpresionProvider.notifier)
            .quitarTodos(partes.map((p) => p.id));
      }
      setState(() => _mensaje = ok
          ? 'Partes enviados a impresión.'
          : 'Impresión cancelada. Los partes siguen en la bandeja.');
    } catch (e) {
      if (mounted) {
        setState(() => _mensaje = 'No se pudo imprimir: ${cleanError(e)}');
      }
    } finally {
      if (mounted) setState(() => _imprimiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final partes = ref.watch(colaImpresionProvider);
    return PopScope(
      canPop: !_imprimiendo,
      child: AlertDialog(
        title: Text('Bandeja de impresión (${partes.length})'),
        content: SizedBox(
          width: 680,
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                  'Una hoja por parte, en el orden de esta lista. Colocá los formularios preimpresos en la impresora.'),
              const SizedBox(height: 8),
              Text('La bandeja se conserva mientras la sesión esté abierta.',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              Expanded(
                child: partes.isEmpty
                    ? const Center(
                        child: Text('No hay partes pendientes de impresión.'))
                    : ListView.separated(
                        itemCount: partes.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final parte = partes[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(child: Text('${index + 1}')),
                            title: Text(parte.empleadoCompleto),
                            subtitle: Text(
                                '${DateFmt.ddmmyyyy(parte.fecha)} · ${parte.tipo.label}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Imprimir este parte',
                                  onPressed: _imprimiendo
                                      ? null
                                      : () => _imprimir([parte]),
                                  icon: const Icon(Icons.print_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Quitar de la bandeja',
                                  onPressed: _imprimiendo
                                      ? null
                                      : () => ref
                                          .read(colaImpresionProvider.notifier)
                                          .quitar(parte.id),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              if (_mensaje != null) ...[
                const SizedBox(height: 12),
                Semantics(liveRegion: true, child: Text(_mensaje!)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _imprimiendo ? null : () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          FilledButton.icon(
            onPressed: _imprimiendo || partes.isEmpty
                ? null
                : () => _imprimir([...partes]),
            icon: _imprimiendo
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.print_outlined),
            label: Text(_imprimiendo
                ? 'Preparando impresión…'
                : 'Imprimir todos (${partes.length})'),
          ),
        ],
      ),
    );
  }
}

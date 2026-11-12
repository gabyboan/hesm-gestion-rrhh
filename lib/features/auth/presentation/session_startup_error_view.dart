import 'package:flutter/material.dart';

import '../../../core/startup/backend_capabilities.dart';

class SessionStartupErrorView extends StatelessWidget {
  const SessionStartupErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    required this.onSignOut,
    this.busy = false,
    this.actionError,
  });

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;
  final bool busy;
  final String? actionError;

  @override
  Widget build(BuildContext context) {
    final needsUpdate = error is BackendUpdateRequired;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          needsUpdate
                              ? Icons.system_update_alt
                              : Icons.cloud_off,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 20),
                      Text(
                          needsUpdate
                              ? 'Actualización de la base pendiente'
                              : 'No se pudo abrir la sesión',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      Text(
                          needsUpdate
                              ? 'La conexión se realizó correctamente. La base necesita actualizarse para esta versión. Cuando el responsable complete la actualización, elegí Reintentar.'
                              : 'No se pudo completar la comprobación de acceso. Revisá la conexión y volvé a intentar.',
                          textAlign: TextAlign.center),
                      if (actionError != null) ...[
                        const SizedBox(height: 12),
                        Text(actionError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ],
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: busy ? null : onRetry,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                          OutlinedButton(
                            onPressed: busy ? null : onSignOut,
                            child: Text(busy
                                ? 'Cerrando sesión…'
                                : 'Volver al inicio de sesión'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

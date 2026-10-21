import 'dart:async';

import 'package:flutter/material.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// Contrato mínimo para monitorear internet y probar la capa visual sin hacer
/// solicitudes de red reales.
abstract interface class InternetMonitor {
  Future<bool> get hasInternet;

  Stream<bool> get onInternetChanged;

  Future<void> dispose();
}

/// Cubre la aplicación mientras no hay acceso real a internet.
///
/// La comprobación usa varios servicios confiables y también el endpoint de
/// la aplicación. Por eso no alcanza con que Windows informe Wi-Fi conectado:
/// debe existir una salida real a internet para quitar el bloqueo.
class InternetConnectionGate extends StatefulWidget {
  const InternetConnectionGate({
    super.key,
    required this.child,
    required this.applicationEndpoint,
    this.onConnectionChanged,
    this.monitor,
  });

  final Widget child;
  final Uri applicationEndpoint;
  final ValueChanged<bool>? onConnectionChanged;

  /// Permite inyectar un verificador controlado en pruebas.
  final InternetMonitor? monitor;

  @override
  State<InternetConnectionGate> createState() => _InternetConnectionGateState();
}

class _InternetConnectionGateState extends State<InternetConnectionGate> {
  static const _checkInterval = Duration(seconds: 5);

  late final InternetMonitor _monitor;
  late final bool _ownsMonitor;
  late final AppLifecycleListener _lifecycleListener;
  StreamSubscription<bool>? _subscription;

  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();

    _ownsMonitor = widget.monitor == null;
    _monitor = widget.monitor ??
        _InternetConnectionMonitor(
          applicationEndpoint: widget.applicationEndpoint,
          checkInterval: _checkInterval,
        );

    _lifecycleListener = AppLifecycleListener(
      onResume: _startMonitoring,
      onPause: _stopMonitoring,
    );
    _startMonitoring();
  }

  void _startMonitoring() {
    unawaited(_subscription?.cancel());
    _subscription = _monitor.onInternetChanged.listen(_setInternetAccess);
    unawaited(_checkInternet());
  }

  void _stopMonitoring() {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  Future<void> _checkInternet() async {
    final hasInternet = await _monitor.hasInternet;
    if (!mounted) return;
    _setInternetAccess(hasInternet);
  }

  void _setInternetAccess(bool hasInternet) {
    if (_hasInternet == hasInternet) return;

    if (!hasInternet) {
      // Evita que un campo que quedó enfocado reciba escritura por teclado.
      FocusManager.instance.primaryFocus?.unfocus();
    }

    setState(() => _hasInternet = hasInternet);
    widget.onConnectionChanged?.call(hasInternet);
  }

  @override
  void dispose() {
    _stopMonitoring();
    _lifecycleListener.dispose();
    if (_ownsMonitor) {
      unawaited(_monitor.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = !_hasInternet;

    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          ignoring: isOffline,
          child: ExcludeFocus(
            excluding: isOffline,
            child: widget.child,
          ),
        ),
        if (isOffline) const _OfflineOverlay(),
      ],
    );
  }
}

class _InternetConnectionMonitor implements InternetMonitor {
  _InternetConnectionMonitor({
    required Uri applicationEndpoint,
    required Duration checkInterval,
  }) : _connection = InternetConnection.createInstance(
          checkInterval: checkInterval,
          customCheckOptions: [
            InternetCheckOption(
              uri: applicationEndpoint,
              // Un 401/404 también confirma que se puede alcanzar el servidor.
              responseStatusFn: (response) => response.statusCode < 500,
            ),
          ],
        );

  final InternetConnection _connection;

  @override
  Future<bool> get hasInternet => _connection.hasInternetAccess;

  @override
  Stream<bool> get onInternetChanged => _connection.onStatusChange.map(
        (status) => status == InternetStatus.connected,
      );

  @override
  Future<void> dispose() => _connection.dispose();
}

class _OfflineOverlay extends StatelessWidget {
  const _OfflineOverlay();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          'Sin internet. La aplicación está pausada hasta recuperar la conexión.',
      child: ColoredBox(
        color: const Color(0xF510131B),
        child: Center(
          child: SafeArea(
            minimum: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    color: Color(0xFFF9FAFB),
                    size: 64,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Sin internet',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: const Color(0xFFF9FAFB),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'La aplicación está temporalmente pausada. '
                    'Podrás seguir trabajando automáticamente cuando vuelva la conexión.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFFD1D5DB),
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: 28),
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFFF9FAFB),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Comprobando la conexión...',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFF9FAFB)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

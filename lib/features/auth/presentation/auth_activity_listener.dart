import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/session_timeout_provider.dart';

/// Detecta actividad del usuario mientras está autenticado.
///
/// Reinicia el control de inactividad ante:
/// - clicks;
/// - movimiento del mouse;
/// - scroll;
/// - teclado.
///
/// Este widget debe envolver solo pantallas protegidas por login.
class AuthActivityListener extends ConsumerStatefulWidget {
  final Widget child;

  const AuthActivityListener({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AuthActivityListener> createState() =>
      _AuthActivityListenerState();
}

class _AuthActivityListenerState extends ConsumerState<AuthActivityListener> {
  DateTime? _lastReset;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      _markActivity();
    }

    // false = no consumimos la tecla, dejamos que la UI siga funcionando normal.
    return false;
  }

  void _markActivity() {
    final now = DateTime.now();

    // Throttle simple para no reiniciar el timer 200 veces por segundo.
    if (_lastReset != null &&
        now.difference(_lastReset!) < const Duration(seconds: 2)) {
      return;
    }

    _lastReset = now;

    unawaited(ref.read(sessionTimeoutProvider).reset());
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _markActivity(),
      onPointerMove: (_) => _markActivity(),
      onPointerSignal: (_) => _markActivity(),
      child: widget.child,
    );
  }
}

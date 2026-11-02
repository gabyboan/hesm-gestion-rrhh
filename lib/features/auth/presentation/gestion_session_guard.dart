import 'dart:async';
import 'dart:convert';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_providers.dart';
import '../application/mfa_providers.dart';
import '../data/gestion_session_repository.dart';
import '../domain/session_verification_window.dart';

/// Cubre el Navigator completo, incluidos diálogos abiertos, al perder el acceso.
class GestionSessionGuard extends ConsumerStatefulWidget {
  const GestionSessionGuard({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<GestionSessionGuard> createState() =>
      _GestionSessionGuardState();
}

enum _Access { checking, admitted, conflict, unavailable }

class _GestionSessionGuardState extends ConsumerState<GestionSessionGuard>
    with WidgetsBindingObserver {
  Timer? _timer;
  String? _binding;
  _Access _access = _Access.checking;
  bool _everAdmitted = false;
  bool _ready = false;
  bool _busy = false;
  bool _closing = false;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    if (_access == _Access.admitted) {
      try {
        await ref
            .read(gestionSessionRepositoryProvider)
            .release()
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        // La reserva del servidor vence aunque el equipo cierre sin conexión.
      }
    }
    return AppExitResponse.exit;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _binding != null && _ready) {
      // Bloquear antes de volver a mostrar los datos de una ventana suspendida.
      setState(() {
        _access = _Access.checking;
        _revision++;
        _busy = false;
      });
      unawaited(_check(acquire: false));
    }
  }

  Future<void> _check({required bool acquire}) async {
    if (_busy || !_ready || _binding == null) return;
    final binding = _binding;
    final revision = ++_revision;
    _busy = true;
    _timer?.cancel();
    try {
      final repository = ref.read(gestionSessionRepositoryProvider);
      final allowed =
          await (acquire ? repository.acquire() : repository.renew())
              .timeout(const Duration(seconds: 12));
      if (!mounted || _binding != binding || _revision != revision) return;
      setState(() {
        _access = allowed ? _Access.admitted : _Access.conflict;
        _everAdmitted |= allowed;
      });
      if (allowed) {
        _timer = Timer(const Duration(seconds: 30),
            () => unawaited(_check(acquire: false)));
      }
    } catch (_) {
      if (mounted && _binding == binding && _revision == revision) {
        setState(() => _access = _Access.unavailable);
      }
    } finally {
      if (_binding == binding && _revision == revision) _busy = false;
    }
  }

  Future<void> _logout() async {
    if (_closing) return;
    setState(() => _closing = true);
    try {
      // Auth elimina exclusivamente esta sesión y la reserva asociada por FK.
      await ref.read(authRepoProvider).signOut();
    } catch (_) {
      // El SDK limpia el estado local incluso si falla la revocación remota.
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    String? binding;
    if (session != null) {
      try {
        final claims = jsonDecode(utf8.decode(base64Url.decode(
            base64Url.normalize(session.accessToken.split('.')[1])))) as Map;
        binding = '${session.user.id}:${claims['session_id']}';
      } catch (_) {
        binding = session.user.id;
      }
    }
    if (_binding != binding) {
      _timer?.cancel();
      _binding = binding;
      _revision++;
      _access = _Access.checking;
      _everAdmitted = _ready = _busy = _closing = false;
    }
    if (session == null) {
      return _render(context, blocked: false, showChild: true);
    }

    final mfa = ref.watch(mfaStatusProvider).valueOrNull;
    final deadline = mfa == null
        ? null
        : sessionVerificationDeadline(session.accessToken,
            mfaEnabled: mfa.enabled);
    final ready = mfa != null &&
        !mfa.requiresChallenge &&
        deadline != null &&
        deadline.isAfter(DateTime.now().toUtc());
    if (!ready) {
      if (_ready) {
        _revision++;
        _busy = false;
      }
      _ready = false;
      _timer?.cancel();
      // El gate MFA y su bloqueo global resuelven el desafío y la revalidación.
      return _render(context, blocked: false, showChild: true);
    }
    if (!_ready) {
      _ready = true;
      _access = _Access.checking;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_check(acquire: true));
      });
    }

    final blocked = _access != _Access.admitted;
    return _render(context, blocked: blocked, showChild: _everAdmitted);
  }

  Widget _render(BuildContext context,
      {required bool blocked, required bool showChild}) {
    // Mantener los mismos ancestros del Navigator al revalidar MFA para no
    // desmontar rutas, formularios o el diálogo de la autenticadora.
    return Stack(fit: StackFit.expand, children: [
      if (showChild)
        ExcludeFocus(
          excluding: blocked,
          child: IgnorePointer(ignoring: blocked, child: widget.child),
        ),
      if (blocked)
        Positioned.fill(
          child: PopScope(
            canPop: false,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      if (_access == _Access.checking) ...[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        const Text('Comprobando sesión de Gestión…'),
                      ] else ...[
                        Text(
                            _access == _Access.conflict
                                ? 'Esta cuenta ya tiene una Gestión abierta'
                                : 'No se pudo comprobar la sesión',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 16),
                        Text(
                          _access == _Access.conflict
                              ? 'Cerrá sesión en la otra ventana o equipo y volvé a intentar. Si la aplicación se cerró de golpe, esperá hasta dos minutos.'
                              : 'Revisá la conexión y reintentá para continuar.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _busy || _closing
                              ? null
                              : () {
                                  setState(() => _access = _Access.checking);
                                  unawaited(_check(acquire: true));
                                },
                          child: const Text('Reintentar'),
                        ),
                        TextButton(
                          onPressed: _closing ? null : _logout,
                          child: const Text('Volver al inicio de sesión'),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

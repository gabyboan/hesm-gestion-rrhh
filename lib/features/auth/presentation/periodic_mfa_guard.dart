import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_providers.dart';
import '../application/mfa_providers.dart';
import '../data/mfa_repository.dart';
import '../domain/session_verification_window.dart';

/// Rodea el Navigator completo: también cubre diálogos, menús y rutas abiertas.
class PeriodicMfaGuard extends ConsumerStatefulWidget {
  const PeriodicMfaGuard({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<PeriodicMfaGuard> createState() => _PeriodicMfaGuardState();
}

class _PeriodicMfaGuardState extends ConsumerState<PeriodicMfaGuard>
    with WidgetsBindingObserver {
  Timer? _timer;
  String? _binding;
  DateTime? _deadline;
  bool _expired = false;
  bool _busy = false;
  bool _closing = false;
  bool _mustConfirm = false;
  String? _error;
  String? _factorId;
  MfaStatus? _lastStatus;
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  void _schedule(String binding, DateTime? deadline) {
    if (_binding == binding && _deadline == deadline) {
      if (deadline != null && !deadline.isAfter(DateTime.now().toUtc())) {
        _expired = true;
      }
      return;
    }
    final changedAccount = _binding != binding;
    _timer?.cancel();
    _binding = binding;
    _deadline = deadline;
    _expired = deadline == null || !deadline.isAfter(DateTime.now().toUtc());
    if (changedAccount) {
      _code.clear();
      _error = null;
      _factorId = null;
      _busy = false;
      _closing = false;
      _mustConfirm = false;
    }
    if (!_expired) {
      _timer = Timer(deadline!.difference(DateTime.now().toUtc()), () {
        if (mounted) setState(() => _expired = true);
      });
    }
  }

  Future<void> _verify(MfaStatus status) async {
    if (_busy || _closing) return;
    final binding = _binding;
    setState(() {
      _busy = true;
      _mustConfirm = true;
      _error = null;
    });
    try {
      final repo = ref.read(mfaRepositoryProvider);
      await repo.verify(
          _factorId ?? status.factors.first.id, _code.text.trim());
      await repo.confirmSessionAccess();
      if (!mounted || _binding != binding) return;
      final session = ref.read(authRepoProvider).session;
      final deadline = session == null
          ? null
          : sessionVerificationDeadline(session.accessToken, mfaEnabled: true);
      if (deadline == null || !deadline.isAfter(DateTime.now().toUtc())) {
        throw StateError('Verificación no actualizada.');
      }
      setState(() {
        _schedule(binding!, deadline);
        _expired = false;
        _mustConfirm = false;
        _code.clear();
      });
    } catch (error) {
      if (mounted && _binding == binding) {
        setState(() {
          _expired = true;
          _error = mfaErrorText(error);
        });
      }
    } finally {
      if (mounted && _binding == binding) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    if (_busy || _closing) return;
    setState(() {
      _closing = true;
      _error = null;
    });
    _code.clear();
    try {
      await ref.read(authRepoProvider).signOut();
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'No se pudo completar el cierre. Volvé a intentar.');
      }
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    if (!ref.watch(mfaUiEnabledProvider) || session == null) {
      _timer?.cancel();
      _binding = null;
      _deadline = null;
      _expired = false;
      _mustConfirm = false;
      _lastStatus = null;
      return widget.child;
    }
    if (_binding != null && _binding != session.user.id) {
      _timer?.cancel();
      _lastStatus = null;
      _binding = null;
      _deadline = null;
      _expired = _mustConfirm = false;
    }
    final currentStatus = ref.watch(mfaStatusProvider).valueOrNull;
    if (currentStatus != null) _lastStatus = currentStatus;
    final alreadyDue =
        _deadline != null && !_deadline!.isAfter(DateTime.now().toUtc());
    final status = currentStatus ??
        ((_expired || _mustConfirm || _busy || alreadyDue)
            ? _lastStatus
            : null);
    // El gate inicial resuelve la carga, los errores y el desafío AAL1.
    if (status == null || (status.enabled && !status.sessionVerified)) {
      return widget.child;
    }
    final deadline = sessionVerificationDeadline(session.accessToken,
        mfaEnabled: status.enabled);
    _schedule(session.user.id, deadline);
    final locked = _expired || _busy || _mustConfirm;
    if (locked && !status.enabled && !_closing && _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _expired) unawaited(_logout());
      });
    }
    return Stack(fit: StackFit.expand, children: [
      ExcludeFocus(
          excluding: locked,
          child: ExcludeSemantics(
              excluding: locked,
              child: Offstage(
                  offstage: locked,
                  child: TickerMode(enabled: !locked, child: widget.child)))),
      if (locked)
        Positioned.fill(
            child: Overlay.wrap(
                child: Actions(
          actions: {
            DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) => null),
          },
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: FocusScope(
                autofocus: true,
                child: Semantics(
                    scopesRoute: true,
                    explicitChildNodes: true,
                    namesRoute: true,
                    label: 'Sesión bloqueada',
                    child: Center(
                        child: SingleChildScrollView(
                      child: AlertDialog(
                        title:
                            const Text('Verificá tu identidad para continuar'),
                        content: SizedBox(
                            width: 360,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(status.enabled
                                      ? 'Pasó una hora desde la última verificación. Ingresá el código de tu autenticadora o cerrá sesión.'
                                      : 'La sesión llegó a su límite de una hora. Volvé a ingresar.'),
                                  if (status.enabled) ...[
                                    const SizedBox(height: 16),
                                    if (status.factors.length > 1)
                                      DropdownButtonFormField<String>(
                                          initialValue: _factorId ??
                                              status.factors.first.id,
                                          items: [
                                            for (final f in status.factors)
                                              DropdownMenuItem(
                                                  value: f.id,
                                                  child: Text(f.name))
                                          ],
                                          onChanged: _busy
                                              ? null
                                              : (v) => setState(
                                                  () => _factorId = v)),
                                    TextField(
                                        controller: _code,
                                        enabled: !_busy && !_closing,
                                        autofocus: true,
                                        keyboardType: TextInputType.number,
                                        maxLength: 6,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly
                                        ],
                                        autofillHints: const [
                                          AutofillHints.oneTimeCode
                                        ],
                                        decoration: const InputDecoration(
                                            labelText:
                                                'Código de seis dígitos'),
                                        onSubmitted: (_) => _verify(status)),
                                  ],
                                  if (_error != null)
                                    Text(_error!,
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error)),
                                ])),
                        actions: [
                          TextButton(
                              onPressed: _busy || _closing ? null : _logout,
                              child: const Text('Cerrar sesión')),
                          if (status.enabled)
                            FilledButton(
                                onPressed: _busy || _closing
                                    ? null
                                    : () => _verify(status),
                                child: Text(_busy
                                    ? 'Verificando…'
                                    : 'Verificar código')),
                        ],
                      ),
                    )))),
          ),
        ))),
    ]);
  }
}

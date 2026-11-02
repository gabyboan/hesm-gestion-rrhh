import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;

import '../application/auth_providers.dart';
import '../application/mfa_providers.dart';
import '../data/mfa_repository.dart';

/// Se resuelve antes de cargar perfiles, preferencias o módulos de la Data API.
class MfaGate extends ConsumerWidget {
  const MfaGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(mfaStatusProvider).when(
          data: (status) => status.requiresChallenge
              ? MfaChallengePage(status: status)
              : child,
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, __) => Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('No se pudo comprobar la seguridad de la sesión.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(mfaStatusProvider),
                    child: const Text('Reintentar'),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        await ref.read(authRepoProvider).signOut();
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text(
                                'No se pudo cerrar sesión. Volvé a intentar.'),
                          ));
                        }
                      }
                    },
                    child: const Text('Volver al inicio de sesión'),
                  ),
                ]),
              ),
            ),
          ),
        );
  }
}

class MfaChallengePage extends ConsumerStatefulWidget {
  const MfaChallengePage({super.key, required this.status});
  final MfaStatus status;
  @override
  ConsumerState<MfaChallengePage> createState() => _MfaChallengePageState();
}

class _MfaChallengePageState extends ConsumerState<MfaChallengePage> {
  final _code = TextEditingController();
  String? _factorId;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(mfaRepositoryProvider).verify(
          _factorId ?? widget.status.factors.first.id, _code.text.trim());
      if (!mounted) return;
      _code.clear();
      ref.invalidate(mfaStatusProvider);
    } catch (error) {
      if (mounted) setState(() => _error = mfaErrorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
                width: 390,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user_outlined, size: 48),
                    const SizedBox(height: 16),
                    Text('Verificación en dos pasos',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    const Text(
                        'Ingresá el código de tu aplicación autenticadora.'),
                    const SizedBox(height: 20),
                    if (widget.status.factors.length > 1)
                      DropdownButtonFormField<String>(
                        initialValue:
                            _factorId ?? widget.status.factors.first.id,
                        items: [
                          for (final factor in widget.status.factors)
                            DropdownMenuItem(
                                value: factor.id, child: Text(factor.name))
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _factorId = value),
                      ),
                    _CodeField(
                        controller: _code, enabled: !_busy, onSubmit: _verify),
                    if (_error != null) _ErrorText(_error!),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: _busy ? null : _verify,
                        child:
                            Text(_busy ? 'Verificando…' : 'Verificar código')),
                    TextButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                try {
                                  await ref.read(authRepoProvider).signOut();
                                } catch (error) {
                                  if (mounted) {
                                    setState(
                                        () => _error = mfaErrorText(error));
                                  }
                                }
                              },
                        child: const Text('Cerrar sesión')),
                    const SizedBox(height: 12),
                    const Text(
                        'Si perdiste el acceso a tu autenticadora, contactá al administrador.',
                        textAlign: TextAlign.center),
                  ],
                )),
          ),
        ),
      );
}

class MfaSettingsTile extends ConsumerWidget {
  const MfaSettingsTile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      !ref.watch(mfaUiEnabledProvider)
          ? const SizedBox.shrink()
          : ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.security_outlined),
              title: const Text('Verificación en dos pasos'),
              subtitle: const Text('Opcional · Aplicación autenticadora'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const MfaSettingsDialog()),
            );
}

class MfaSettingsDialog extends ConsumerStatefulWidget {
  const MfaSettingsDialog({super.key});
  @override
  ConsumerState<MfaSettingsDialog> createState() => _MfaSettingsDialogState();
}

class _MfaSettingsDialogState extends ConsumerState<MfaSettingsDialog> {
  final _code = TextEditingController();
  late final MfaRepository _repository;
  MfaStatus? _status;
  MfaEnrollment? _enrollment;
  String? _error;
  bool _busy = true;
  bool _verifying = false;
  String? _boundUserId;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(mfaRepositoryProvider);
    _boundUserId = ref.read(authSessionProvider).valueOrNull?.user.id;
    ref.listenManual(authSessionProvider, (previous, next) {
      if (!next.hasValue) return;
      final userId = next.valueOrNull?.user.id;
      if (_boundUserId == null) {
        _boundUserId = userId;
      } else if (userId != _boundUserId) {
        // Un diálogo con QR/clave no debe sobrevivir a logout o cambio de cuenta.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        });
      }
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final status = await _repository.loadStatus();
      if (mounted) setState(() => _status = status);
    } catch (error) {
      if (mounted) setState(() => _error = mfaErrorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelPending(MfaEnrollment enrollment) async {
    try {
      await _repository.unenroll(enrollment.id);
    } catch (_) {
      // Un factor no verificado no activa MFA. Nunca registrar el secreto.
    }
  }

  @override
  void dispose() {
    final pending = _enrollment;
    if (pending != null && !_verifying) unawaited(_cancelPending(pending));
    _enrollment = null;
    _code.dispose();
    super.dispose();
  }

  Future<void> _enroll() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final enrollment = await _repository.enroll();
      if (!mounted) {
        await _cancelPending(enrollment);
        return;
      }
      setState(() => _enrollment = enrollment);
    } catch (error) {
      if (mounted) setState(() => _error = mfaErrorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final pending = _enrollment;
    if (_busy || pending == null) return;
    setState(() {
      _busy = true;
      _verifying = true;
      _error = null;
    });
    var verified = false;
    try {
      await _repository.verify(pending.id, _code.text.trim());
      verified = true;
      _enrollment = null;
      if (!mounted) return;
      _code.clear();
      ref.invalidate(mfaStatusProvider);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = mfaErrorText(error));
    } finally {
      _verifying = false;
      if (!mounted && !verified) unawaited(_cancelPending(pending));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(MfaFactorInfo factor) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Desactivar doble factor'),
              content: const Text(
                  'Esta autenticadora dejará de proteger tu cuenta.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Desactivar')),
              ],
            ));
    if (confirmed != true || !mounted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository.unenroll(factor.id);
      if (!mounted) return;
      ref.invalidate(mfaStatusProvider);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = mfaErrorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy,
        child: AlertDialog(
          title: const Text('Verificación en dos pasos'),
          content: SizedBox(
              width: 390,
              child: SingleChildScrollView(
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Es opcional. Si la activás, se pedirá un código de tu autenticadora al iniciar sesión.'),
                  const SizedBox(height: 16),
                  if (_busy) const LinearProgressIndicator(),
                  if (_enrollment case final enrollment?) ...[
                    const Text('Escaneá este QR con tu autenticadora:'),
                    Center(
                        child: SizedBox.square(
                            dimension: 220,
                            child: CustomPaint(
                                painter:
                                    _EnrollmentQrPainter(enrollment.uri)))),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Ingresar la clave manualmente'),
                      children: [SelectableText(enrollment.secret)],
                    ),
                    _CodeField(
                        controller: _code, enabled: !_busy, onSubmit: _confirm),
                    const Text(
                        'Al activar se cerrarán tus otras sesiones. Guardá acceso a tu autenticadora.'),
                  ] else if (_status?.enabled == true) ...[
                    const Text('Doble factor activado.',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    for (final factor in _status!.factors)
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(factor.name),
                          trailing: TextButton(
                              onPressed: _busy ? null : () => _remove(factor),
                              child: const Text('Desactivar'))),
                  ] else if (_status != null)
                    FilledButton.icon(
                        onPressed: _busy ? null : _enroll,
                        icon: const Icon(Icons.add_moderator_outlined),
                        label: const Text('Configurar autenticadora')),
                  if (_error != null) _ErrorText(_error!),
                  if (_status == null && !_busy)
                    TextButton(
                        onPressed: () {
                          setState(() {
                            _busy = true;
                            _error = null;
                          });
                          _load();
                        },
                        child: const Text('Reintentar')),
                  const SizedBox(height: 12),
                  const Text(
                      'Si perdés el celular, contactá al administrador para recuperar el acceso.'),
                ],
              ))),
          actions: [
            TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: Text(_enrollment == null ? 'Cerrar' : 'Cancelar')),
            if (_enrollment != null)
              FilledButton(
                  onPressed: _busy ? null : _confirm,
                  child: const Text('Activar con código')),
          ],
        ),
      );
}

class _CodeField extends StatelessWidget {
  const _CodeField(
      {required this.controller,
      required this.enabled,
      required this.onSubmit});
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmit;
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
            labelText: 'Código de seis dígitos', border: OutlineInputBorder()),
        onSubmitted: (_) => onSubmit(),
      );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(text,
          style: TextStyle(color: Theme.of(context).colorScheme.error)));
}

class _EnrollmentQrPainter extends CustomPainter {
  const _EnrollmentQrPainter(this.uri);
  final String uri;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final margin = size.shortestSide / 10;
    final bars = pw.Barcode.qrCode().make(uri,
        width: size.width - margin * 2,
        height: size.height - margin * 2,
        drawText: false);
    final paint = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    for (final bar in bars) {
      if (bar is pw.BarcodeBar && bar.black) {
        canvas.drawRect(
            Rect.fromLTWH(
                margin + bar.left, margin + bar.top, bar.width, bar.height),
            paint);
      }
    }
  }

  @override
  bool shouldRepaint(_EnrollmentQrPainter oldDelegate) =>
      oldDelegate.uri != uri;
}

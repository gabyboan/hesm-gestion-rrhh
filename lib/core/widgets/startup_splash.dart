import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../startup/startup_checks.dart';
import '../updates/startup_update.dart';
import '../updates/windows_update_service.dart';

class HesmMark extends StatelessWidget {
  final double size;
  final double rotation;

  const HesmMark({super.key, this.size = 64, this.rotation = 0});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'HESM Gestión RRHH',
        image: true,
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: _HesmLogoPainter(rotation: rotation)),
        ),
      );
}

class HesmAnimatedMark extends StatefulWidget {
  const HesmAnimatedMark({super.key, this.size = 64});
  final double size;

  @override
  State<HesmAnimatedMark> createState() => _HesmAnimatedMarkState();
}

class _HesmAnimatedMarkState extends State<HesmAnimatedMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 8000),
  );
  late final Animation<double> _turns = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: 0.125)
          .chain(CurveTween(curve: Curves.easeInCubic)),
      weight: 15,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.125, end: 0.75)
          .chain(CurveTween(curve: Curves.easeInQuad)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.75, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.875)
          .chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 10,
    ),
    TweenSequenceItem(tween: ConstantTween(0.875), weight: 5),
  ]).animate(_rotation);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _rotation.stop();
      _rotation.value = 0;
    } else if (!_rotation.isAnimating) {
      _rotation.repeat();
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ocho dientes: al retroceder 1/8 de vuelta el ciclo encaja sin saltos.
    return AnimatedBuilder(
      animation: _turns,
      builder: (_, __) =>
          HesmMark(size: widget.size, rotation: _turns.value * 2 * math.pi),
    );
  }
}

class StartupSplash extends StatefulWidget {
  const StartupSplash(
      {super.key,
      this.checks = const [],
      this.onRetry,
      this.onReady,
      this.version = WindowsUpdateService.version,
      this.updates = const StartupUpdateState(StartupUpdateStatus.disabled),
      this.onInstallUpdate,
      this.onIgnoreUpdate});
  final List<StartupCheckState> checks;
  final VoidCallback? onRetry;
  final VoidCallback? onReady;
  final String version;
  final StartupUpdateState updates;
  final VoidCallback? onInstallUpdate;
  final VoidCallback? onIgnoreUpdate;

  @override
  State<StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<StartupSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200))
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _notifyReady();
    });
  bool _started = false;
  bool _notified = false;

  void _notifyReady() {
    if (_notified) return;
    _notified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady?.call();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else if (!_started) {
      _entrance.forward();
    }
    _started = true;
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checks = widget.checks;
    final failed = checks.any((check) => check.status == CheckStatus.failed);
    final servicesPassed =
        checks.where((c) => c.status == CheckStatus.passed).length;
    final showUpdates = widget.updates.status != StartupUpdateStatus.disabled;
    final passed = servicesPassed +
        (widget.updates.status == StartupUpdateStatus.current ? 1 : 0);
    final total = checks.length + (showUpdates ? 1 : 0);
    final updateMessage = servicesPassed == checks.length && checks.isNotEmpty
        ? switch (widget.updates.status) {
            StartupUpdateStatus.checking => 'Buscando actualizaciones...',
            StartupUpdateStatus.available =>
              'Actualización pendiente. Podés instalarla o continuar.',
            StartupUpdateStatus.notConfigured =>
              'Servicios listos. Falta configurar las actualizaciones.',
            StartupUpdateStatus.unavailable =>
              'Servicios listos. No se pudo comprobar la versión.',
            _ => null,
          }
        : null;
    final scaler = MediaQuery.textScalerOf(context);
    final brandHeight =
        128 + 12 + scaler.scale(34) * 1.1 + 4 + scaler.scale(12) * 1.3;
    return Scaffold(
      backgroundColor: const Color(0xFF080F19),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.7),
            radius: 1.1,
            colors: [Color(0xFF12383E), Color(0xFF080F19)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            Widget bounded(Widget child) => Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: child));
            final cards = Column(mainAxisSize: MainAxisSize.min, children: [
              if (showUpdates) ...[
                _StartupUpdateCard(
                  state: widget.updates,
                  installedVersion: widget.version,
                  onInstall: widget.onInstallUpdate,
                  onIgnore: widget.onIgnoreUpdate,
                ),
                const SizedBox(height: 10),
              ],
              for (final check in checks) ...[
                _StartupCheckCard(state: check),
                const SizedBox(height: 10),
              ],
            ]);
            final summary = _StartupSummary(
                passed: passed,
                total: total,
                failed: failed,
                message: updateMessage,
                onRetry: widget.onRetry);
            return AnimatedBuilder(
              animation: _entrance,
              builder: (context, child) {
                final movement =
                    const Interval(1 / 2.2, 1, curve: Curves.easeOutCubic)
                        .transform(_entrance.value);
                final reveal = const Interval(1 / 2.2, 1, curve: Curves.easeOut)
                    .transform(_entrance.value);
                final scale = 1 - 0.4 * movement;
                final initialTop =
                    math.max(16.0, (constraints.maxHeight - brandHeight) / 2);
                final top = initialTop + (20 - initialTop) * movement;
                return Stack(children: [
                  Positioned.fill(
                    top: 20 + brandHeight * 0.6 + 18,
                    child: IgnorePointer(
                      ignoring: reveal < 1,
                      child: ExcludeSemantics(
                        excluding: reveal < 1,
                        child: Opacity(
                          opacity: reveal,
                          child: Transform.translate(
                            offset: Offset(0, 30 * (1 - reveal)),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: top,
                    left: (constraints.maxWidth - 320 * scale) / 2,
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.topLeft,
                      child: const SizedBox(
                        width: 320,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: Color(0x3319B4AA),
                                    blurRadius: 45,
                                    spreadRadius: 4)
                              ],
                            ),
                            child: HesmAnimatedMark(size: 128),
                          ),
                          SizedBox(height: 12),
                          Text('HESM',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 3)),
                          SizedBox(height: 4),
                          Text('GESTIÓN RRHH',
                              style: TextStyle(
                                  color: Color(0xFFB6D8D9),
                                  fontSize: 12,
                                  height: 1.3,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 3)),
                        ]),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Semantics(
                      label: 'Versión instalada ${widget.version}',
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth:
                                math.min(180, constraints.maxWidth * 0.3)),
                        child: Text('v${widget.version}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                color: Color(0xFFB6D8D9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ]);
              },
              child: constraints.maxHeight < 600 || scaler.scale(14) > 20
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: bounded(Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            cards,
                            const SizedBox(height: 6),
                            summary
                          ])),
                    )
                  : Column(children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: bounded(cards),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                        child: bounded(summary),
                      ),
                    ]),
            );
          }),
        ),
      ),
    );
  }
}

class _StartupCheckCard extends StatelessWidget {
  const _StartupCheckCard({required this.state});
  final StartupCheckState state;

  String get _description {
    if (state.message != null) return state.message!;
    if (state.status == CheckStatus.pending) return 'Esperando turno...';
    final passed = state.status == CheckStatus.passed;
    return switch (state.check) {
      StartupCheck.configuration => passed
          ? 'Configuración validada.'
          : 'Validando la configuración de inicio...',
      StartupCheck.dns => passed
          ? 'Nombre del servidor resuelto.'
          : 'Buscando el servidor por su nombre...',
      StartupCheck.internet => passed
          ? 'Conexión HTTPS y certificado válidos.'
          : 'Comprobando la conexión segura...',
      StartupCheck.authentication => passed
          ? 'El servicio de acceso responde.'
          : 'Consultando el servicio de acceso...',
      StartupCheck.data => passed
          ? 'API disponible para iniciar sesión.'
          : 'Comprobando la disponibilidad de los datos...',
      StartupCheck.application => passed
          ? 'Sistema preparado para ingresar.'
          : 'Preparando el sistema...',
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (state.status) {
      CheckStatus.passed => const Color(0xFF6EE7B7),
      CheckStatus.failed => const Color(0xFFFFB4AB),
      CheckStatus.running => const Color(0xFF8FE4DE),
      CheckStatus.pending => const Color(0xFF8297A9),
    };
    final statusText = switch (state.status) {
      CheckStatus.passed => 'Listo',
      CheckStatus.failed => 'Error',
      CheckStatus.running => 'Verificando',
      CheckStatus.pending => 'En espera',
    };
    return Semantics(
      label: '${state.check.label}: $statusText',
      liveRegion: state.status == CheckStatus.failed,
      child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: state.status == CheckStatus.running
                ? const Color(0xFF123038)
                : const Color(0xFF111E2B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: state.status == CheckStatus.pending
                    ? const Color(0xFF253746)
                    : color.withValues(alpha: 0.65)),
          ),
          child: Row(
            children: [
              SizedBox(
                  width: 22,
                  height: 22,
                  child: state.status == CheckStatus.running
                      ? CircularProgressIndicator(strokeWidth: 2, color: color)
                      : Icon(
                          switch (state.status) {
                            CheckStatus.passed => Icons.check_circle_rounded,
                            CheckStatus.failed => Icons.cancel_rounded,
                            _ => Icons.radio_button_unchecked,
                          },
                          color: color,
                          size: 22)),
              const SizedBox(width: 13),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(state.check.label,
                        style: const TextStyle(
                            color: Color(0xFFE7EFF3),
                            fontSize: 14,
                            height: 1.3,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(_description,
                        style: TextStyle(
                            color: state.status == CheckStatus.failed
                                ? const Color(0xFFFFDAD6)
                                : const Color(0xFF9BB0C0),
                            fontSize: 12,
                            height: 1.4)),
                  ])),
              if (state.status != CheckStatus.passed) ...[
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(30)),
                  child: Text(statusText,
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          )),
    );
  }
}

class _StartupUpdateCard extends StatelessWidget {
  const _StartupUpdateCard(
      {required this.state,
      required this.installedVersion,
      required this.onInstall,
      required this.onIgnore});
  final StartupUpdateState state;
  final String installedVersion;
  final VoidCallback? onInstall;
  final VoidCallback? onIgnore;

  @override
  Widget build(BuildContext context) {
    final checking = state.status == StartupUpdateStatus.checking;
    final current = state.status == StartupUpdateStatus.current;
    final available = state.status == StartupUpdateStatus.available;
    final color = current
        ? const Color(0xFF6EE7B7)
        : checking
            ? const Color(0xFF8FE4DE)
            : const Color(0xFFF4CB82);
    final title = switch (state.status) {
      StartupUpdateStatus.current => 'Sistema actualizado',
      StartupUpdateStatus.available => 'Actualización pendiente',
      StartupUpdateStatus.checking => 'Actualizaciones del sistema',
      StartupUpdateStatus.notConfigured => 'Actualizaciones sin configurar',
      _ => 'No se pudo comprobar actualizaciones',
    };
    final description = switch (state.status) {
      StartupUpdateStatus.current =>
        'La versión $installedVersion está al día.',
      StartupUpdateStatus.available =>
        'Disponible: ${state.release?.version}. Podés instalarla o ignorarla y continuar.',
      StartupUpdateStatus.checking =>
        'Consultando la versión publicada por el hospital...',
      StartupUpdateStatus.notConfigured =>
        'Podés elegir la carpeta del hospital desde Configuración.',
      _ =>
        'No se pudo verificar la carpeta del hospital. Podés continuar y buscar más tarde.',
    };
    return Semantics(
      liveRegion: available,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111E2B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.65)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 22,
                height: 22,
                child: checking
                    ? CircularProgressIndicator(strokeWidth: 2, color: color)
                    : Icon(
                        current
                            ? Icons.check_circle_rounded
                            : available
                                ? Icons.system_update_alt
                                : Icons.info_outline,
                        color: color,
                        size: 22)),
            const SizedBox(width: 13),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          color: Color(0xFFE7EFF3),
                          fontSize: 14,
                          height: 1.3,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(description,
                      style: const TextStyle(
                          color: Color(0xFFB6CED8), fontSize: 12, height: 1.4)),
                ])),
          ]),
          if (available) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 8, children: [
              FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF156B6B),
                      foregroundColor: Colors.white),
                  onPressed: onInstall,
                  icon: const Icon(Icons.system_update_alt),
                  label: const Text('Instalar y reiniciar')),
              TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFB6D8D9)),
                  onPressed: onIgnore,
                  child: const Text('Ignorar y continuar')),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _StartupSummary extends StatelessWidget {
  const _StartupSummary(
      {required this.passed,
      required this.total,
      required this.failed,
      this.message,
      required this.onRetry});
  final int passed;
  final int total;
  final bool failed;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final complete = total > 0 && passed == total;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF182A35),
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
              child: Text('Verificaciones de inicio',
                  style: TextStyle(color: Color(0xFFB6CED8), fontSize: 13))),
          if (total > 0)
            Text('$passed de $total',
                style: const TextStyle(
                    color: Color(0xFF6EE7B7),
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        LinearProgressIndicator(
            value: total == 0 ? null : passed / total,
            minHeight: 3,
            borderRadius: BorderRadius.circular(3),
            color: failed ? const Color(0xFFFFB4AB) : const Color(0xFF6EE7B7),
            backgroundColor: const Color(0xFF2C4351)),
        const SizedBox(height: 12),
        Text(
            failed
                ? 'No podemos continuar con el inicio.'
                : message ??
                    (complete
                        ? 'Todo listo. Ingresando...'
                        : 'Preparando tu espacio de trabajo...'),
            style: TextStyle(
                color:
                    failed ? const Color(0xFFFFB4AB) : const Color(0xFFB6CED8),
                fontSize: 13,
                height: 1.4)),
        if (failed) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF156B6B),
                  foregroundColor: Colors.white),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar')),
        ],
      ]),
    );
  }
}

class _HesmLogoPainter extends CustomPainter {
  final double rotation;

  const _HesmLogoPainter({required this.rotation});

  static const _institutional = Color(0xFF045E63);
  static const _gear = Color(0xFF263C4D);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 512;
    canvas.save();
    canvas.translate(
      (size.width - 512 * scale) / 2,
      (size.height - 512 * scale) / 2,
    );
    canvas.scale(scale);

    canvas.drawCircle(
      const Offset(256, 256),
      250,
      Paint()..color = _institutional,
    );

    canvas.save();
    canvas.translate(256, 256);
    canvas.rotate(rotation);
    canvas.translate(-256, -256);
    final gearPaint = Paint()..color = _gear;
    canvas.drawCircle(const Offset(256, 256), 151, gearPaint);
    for (var angle = 0; angle < 360; angle += 45) {
      canvas.save();
      canvas.translate(256, 256);
      canvas.rotate(angle * math.pi / 180);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-30, -182, 60, 112),
          const Radius.circular(5),
        ),
        gearPaint,
      );
      canvas.restore();
    }
    canvas.restore();

    canvas.drawCircle(
      const Offset(256, 256),
      99,
      Paint()..color = const Color(0xFFA8E8E9),
    );
    canvas.drawCircle(
      const Offset(256, 256),
      86,
      Paint()..color = const Color(0xFFF7FBFB),
    );

    final suitPaint = Paint()..color = const Color(0xFF30495D);
    final suit = Path()
      ..moveTo(211, 292)
      ..lineTo(211, 280)
      ..cubicTo(211, 261, 226, 246, 245, 246)
      ..lineTo(267, 246)
      ..cubicTo(286, 246, 301, 261, 301, 280)
      ..lineTo(301, 292)
      ..close();
    canvas.drawPath(suit, suitPaint);

    final shirtPaint = Paint()..color = const Color(0xFFF5F7F6);
    canvas.drawPath(
      Path()
        ..moveTo(241, 246)
        ..lineTo(256, 263)
        ..lineTo(249, 270)
        ..lineTo(238, 252)
        ..close(),
      shirtPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(271, 246)
        ..lineTo(256, 263)
        ..lineTo(263, 270)
        ..lineTo(274, 252)
        ..close(),
      shirtPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(253, 260)
        ..lineTo(259, 260)
        ..lineTo(266, 292)
        ..lineTo(246, 292)
        ..close(),
      Paint()..color = const Color(0xFFE4A92F),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(249, 234, 14, 18),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFFEDBD92),
    );
    canvas.drawOval(
      const Rect.fromLTWH(234, 189, 44, 54),
      Paint()..color = const Color(0xFFF3C9A3),
    );
    final hairPaint = Paint()..color = const Color(0xFF303238);
    final hair = Path()
      ..moveTo(234, 215)
      ..cubicTo(232, 196, 242, 181, 259, 181)
      ..cubicTo(276, 181, 285, 194, 282, 212)
      ..cubicTo(277, 209, 273, 203, 271, 196)
      ..cubicTo(261, 204, 249, 209, 235, 209)
      ..close();
    canvas.drawPath(hair, hairPaint);
    canvas.drawPath(
      Path()
        ..moveTo(235, 207)
        ..lineTo(242, 208)
        ..lineTo(242, 229)
        ..lineTo(237, 222)
        ..close(),
      hairPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(277, 207)
        ..lineTo(270, 208)
        ..lineTo(270, 229)
        ..lineTo(275, 222)
        ..close(),
      hairPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_HesmLogoPainter oldDelegate) =>
      oldDelegate.rotation != rotation;
}

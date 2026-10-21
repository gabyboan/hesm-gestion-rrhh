import 'dart:math' as math;

import 'package:flutter/material.dart';

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

class StartupSplash extends StatefulWidget {
  const StartupSplash({super.key});

  @override
  State<StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<StartupSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFF102C3D),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF102C3D), Color(0xFF064C52)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 184,
                  height: 184,
                  child: AnimatedBuilder(
                    animation: _rotation,
                    builder: (context, _) => HesmMark(
                      size: 184,
                      rotation:
                          reduceMotion ? 0 : _rotation.value * 2 * math.pi,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'HESM',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'GESTIÓN RRHH',
                  style: TextStyle(
                    color: Color(0xFFB6D8D9),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Personas. Información. Gestión.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFD7E7EB), fontSize: 16),
                ),
                const SizedBox(height: 28),
                const SizedBox(
                  width: 150,
                  child: LinearProgressIndicator(
                    color: Color(0xFF6FD2C6),
                    backgroundColor: Color(0xFF2D5863),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Preparando tu espacio de trabajo...',
                  style: TextStyle(
                    color: Color(0xFFB6D8D9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

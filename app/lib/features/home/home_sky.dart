/// The home sky: SceneLex's visual signature, drawn natively in Flutter —
/// night gradient, aurora band, hills and breathing sparks. No screenshots,
/// no WebView; animation halts under reduced motion.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../../ui/theme/scenelex_tokens.dart';

class HomeSky extends StatefulWidget {
  const HomeSky({super.key});

  @override
  State<HomeSky> createState() => _HomeSkyState();
}

class _HomeSkyState extends State<HomeSky> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late bool _reduceMotion;

  @override
  void initState() {
    super.initState();
    _reduceMotion = false;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _controller.stop();
      _controller.value = 0;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _SkyPainter(
            animation: _controller,
            reduceMotion: _reduceMotion,
            size: size,
          ),
        ),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({
    required this.animation,
    required this.reduceMotion,
    required this.size,
  }) {
    final rng = Random(42); // deterministic sky
    _sparks = List.generate(reduceMotion ? 0 : 46, (i) {
      final x = rng.nextDouble();
      final depth = 1 - rng.nextDouble() * 0.75; // 1 = far horizon
      final y = 0.16 + depth * 0.62;
      return _Spark(
        x: x,
        y: y,
        radius: 0.7 + rng.nextDouble() * 1.7,
        opacity: (0.25 + rng.nextDouble() * 0.65) * depth,
        phase: rng.nextDouble() * 2 * pi,
      );
    });
  }

  final Animation<double>? animation;
  final bool reduceMotion;
  final Size size;
  late final List<_Spark> _sparks;

  @override
  void paint(Canvas canvas, Size size) {
    _paintSky(canvas, size);
    _paintAurora(canvas, size);
    _paintHills(canvas, size);
    _paintSparks(canvas, size);
  }

  void _paintSky(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: kHomeNightGradient,
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _paintAurora(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader =
          LinearGradient(
            colors: [
              kHomeAuroraTop.withValues(alpha: 0.55),
              kColorEmber.withValues(alpha: 0.28),
              kHomeAuroraMid.withValues(alpha: 0.45),
              kHomeAuroraBottom.withValues(alpha: 0.38),
            ],
          ).createShader(
            Rect.fromLTWH(
              0,
              size.height * 0.10,
              size.width,
              size.height * 0.34,
            ),
          );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          -size.width * 0.25,
          size.height * 0.09,
          size.width * 1.5,
          size.height * 0.38,
        ),
        const Radius.circular(90),
      ),
      paint..maskFilter = MaskFilter.blur(BlurStyle.normal, 34),
    );
  }

  void _paintHills(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFFECD8).withValues(alpha: 0.55),
              kHomeHill.withValues(alpha: 0.38),
              kHomeAuroraMid.withValues(alpha: 0.16),
            ],
          ).createShader(
            Rect.fromLTWH(0, size.height * 0.62, size.width, size.height * 0.4),
          );
    final path = Path()
      ..moveTo(0, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.60,
        size.width * 0.5,
        size.height * 0.70,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.80,
        size.width,
        size.height * 0.72,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      path,
      paint..maskFilter = MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  void _paintSparks(Canvas canvas, Size size) {
    final t = reduceMotion ? 0.5 : (animation?.value ?? 0.5);
    for (final s in _sparks) {
      final twinkle =
          0.25 + 0.75 * (0.5 + 0.5 * sin(2 * pi * t * 1.4 + s.phase));
      final paint = Paint()
        ..color = kHomeSpark.withValues(alpha: s.opacity * twinkle)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SkyPainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.reduceMotion != reduceMotion;
}

class _Spark {
  const _Spark({
    required this.x,
    required this.y,
    required this.radius,
    required this.opacity,
    required this.phase,
  });

  final double x;
  final double y;
  final double radius;
  final double opacity;
  final double phase;
}

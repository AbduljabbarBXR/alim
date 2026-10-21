import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The fixed arabesque behind every screen. Because it sits under the
/// navigator, pages scroll over it and the art itself never moves.
class AlimBackdrop extends StatelessWidget {
  const AlimBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ArabesquePainter(dark: dark),
        size: Size.infinite,
      ),
    );
  }
}

/// Shared [MaterialApp.builder] so the art sits behind every route, splash
/// and error screen alike.
Widget alimBackdropBuilder(BuildContext context, Widget? child) {
  return Stack(
    children: [
      const Positioned.fill(child: AlimBackdrop()),
      if (child != null) Positioned.fill(child: child),
    ],
  );
}

class _ArabesquePainter extends CustomPainter {
  const _ArabesquePainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              dark
                  ? const [
                    Color(0xFF07110E),
                    Color(0xFF11231C),
                    Color(0xFF0B1A15),
                  ]
                  : const [
                    Color(0xFFFCF8EE),
                    Color(0xFFF4EAD5),
                    Color(0xFFF8F1E1),
                  ],
          stops: const [0, 0.62, 1],
        ).createShader(rect),
    );
    _lattice(canvas, size);
  }

  void _lattice(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = AlimColors.gold.withValues(alpha: dark ? 0.075 : 0.06);
    const step = 118.0;
    var row = 0;
    for (var y = -step * 0.4; y < size.height + step; y += step) {
      final shift = row.isOdd ? step / 2 : 0.0;
      for (var x = -step * 0.4 + shift; x < size.width + step; x += step) {
        _star(canvas, Offset(x, y), step * 0.40, step * 0.145, paint);
      }
      row++;
    }
  }

  void _star(
    Canvas canvas,
    Offset center,
    double outer,
    double inner,
    Paint paint,
  ) {
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final angle = -math.pi / 2 + i * math.pi / 8;
      final radius = i.isEven ? outer : inner;
      final point =
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArabesquePainter oldDelegate) =>
      oldDelegate.dark != dark;
}

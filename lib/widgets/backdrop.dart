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

/// Shared [MaterialApp.builder] so the art and the gold frame sit behind and
/// over every route, splash and error screen alike.
Widget alimBackdropBuilder(BuildContext context, Widget? child) {
  return Stack(
    children: [
      const Positioned.fill(child: AlimBackdrop()),
      if (child != null) Positioned.fill(child: child),
      const Positioned.fill(child: IgnorePointer(child: AlimFrame())),
    ],
  );
}

/// A double gold rule with star corners, laid over the whole app the way a
/// manuscript page is set inside its frame.
class AlimFrame extends StatelessWidget {
  const AlimFrame({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      minimum: const EdgeInsets.all(3),
      child: CustomPaint(
        painter: _FramePainter(dark: dark),
        size: Size.infinite,
      ),
    );
  }
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

    final short = math.min(size.width, size.height);
    _medallion(
      canvas,
      Offset(size.width * 0.86, size.height * 0.11),
      short * 0.40,
    );
    _medallion(
      canvas,
      Offset(size.width * 0.02, size.height * 0.88),
      short * 0.30,
    );

    _lattice(canvas, size);
    _watermark(canvas, size);
  }

  void _lattice(Canvas canvas, Size size) {
    final gold = AlimColors.gold.withValues(alpha: dark ? 0.13 : 0.115);
    final leaf = (dark ? AlimColors.leafTint : AlimColors.leafDeep).withValues(
      alpha: dark ? 0.055 : 0.035,
    );
    final goldPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = gold;
    final leafPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = leaf;

    const step = 138.0;
    final centers = <Offset>[];
    var row = 0;
    for (var y = -step * 0.5; y < size.height + step; y += step) {
      final shift = row.isOdd ? step / 2 : 0.0;
      for (var x = -step * 0.5 + shift; x < size.width + step; x += step) {
        centers.add(Offset(x, y));
      }
      row++;
    }

    for (final c in centers) {
      _star(canvas, c, step * 0.25, step * 0.108, goldPaint);
      canvas.drawCircle(c, step * 0.30, leafPaint);
    }

    for (var i = 0; i < centers.length; i++) {
      final c = centers[i];
      for (var j = i + 1; j < centers.length; j++) {
        final other = centers[j];
        if ((other - c).distance <= step * 1.05) {
          canvas.drawLine(c, other, leafPaint);
        }
      }
    }
  }

  void _medallion(Canvas canvas, Offset center, double radius) {
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = AlimColors.gold.withValues(alpha: dark ? 0.10 : 0.085);
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(center, radius * 0.86, paint);
    _star(canvas, center, radius * 0.82, radius * 0.64, paint);
    _star(canvas, center, radius * 0.56, radius * 0.42, paint);
    _star(canvas, center, radius * 0.30, radius * 0.20, paint);
    for (var i = 0; i < 16; i++) {
      final angle = i * math.pi / 8;
      final from =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius * 0.86);
      final to =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius * 0.995);
      canvas.drawLine(from, to, paint);
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

  void _watermark(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'قرآن',
        style: TextStyle(
          fontFamily: quranFamily,
          fontSize: math.min(size.width, size.height) * 0.42,
          height: 1,
          color: AlimColors.gold.withValues(alpha: dark ? 0.05 : 0.045),
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    canvas.save();
    canvas.translate(size.width - painter.width * 0.55, size.height * 0.58);
    canvas.rotate(-0.07);
    painter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArabesquePainter oldDelegate) =>
      oldDelegate.dark != dark;
}

class _FramePainter extends CustomPainter {
  const _FramePainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 80 || size.height < 80) return;
    final gold = AlimColors.gold;
    final outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
      const Radius.circular(20),
    );
    canvas.drawRRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = gold.withValues(alpha: dark ? 0.30 : 0.36),
    );
    canvas.drawRRect(
      outer.deflate(4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = gold.withValues(alpha: dark ? 0.15 : 0.20),
    );

    final cornerPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = gold.withValues(alpha: dark ? 0.35 : 0.42);
    for (final c in [
      Offset(4, 4),
      Offset(size.width - 4, 4),
      Offset(4, size.height - 4),
      Offset(size.width - 4, size.height - 4),
    ]) {
      _cornerStar(canvas, c, 7, cornerPaint);
    }
  }

  void _cornerStar(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final angle = -math.pi / 2 + i * math.pi / 4;
      final radius = i.isEven ? r : r * 0.45;
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
  bool shouldRepaint(covariant _FramePainter oldDelegate) =>
      oldDelegate.dark != dark;
}

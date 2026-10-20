import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

const _arabicDigits = '٠١٢٣٤٥٦٧٨٩';

/// Turns 114 into ١١٤ for the ayah rosettes and page marks.
String quranDigits(int number) =>
    '$number'.split('').map((d) => _arabicDigits[int.parse(d)]).join();

/// The small Kaaba or mosque that opens a surah banner.
class RevelationGlyph extends StatelessWidget {
  const RevelationGlyph({
    super.key,
    required this.revelation,
    this.size = 24,
    required this.color,
  });

  final String revelation;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RevelationPainter(
          madina: revelation == 'Madina',
          color: color,
        ),
      ),
    );
  }
}

class _RevelationPainter extends CustomPainter {
  _RevelationPainter({required this.madina, required this.color});

  final bool madina;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, s * 0.055)
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round;
    final fill =
        Paint()
          ..color = color.withValues(alpha: 0.10)
          ..style = PaintingStyle.fill;

    if (madina) {
      final base = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.16, s * 0.56, s * 0.68, s * 0.30),
        Radius.circular(s * 0.03),
      );
      canvas.drawRRect(base, fill);
      canvas.drawRRect(base, stroke);
      final dome =
          Path()
            ..moveTo(s * 0.22, s * 0.56)
            ..arcToPoint(
              Offset(s * 0.78, s * 0.56),
              radius: Radius.circular(s * 0.34),
              clockwise: true,
            )
            ..close();
      canvas.drawPath(dome, fill);
      canvas.drawPath(dome, stroke);
      canvas.drawLine(
        Offset(s * 0.5, s * 0.18),
        Offset(s * 0.5, s * 0.24),
        stroke,
      );
      canvas.drawCircle(Offset(s * 0.5, s * 0.18), s * 0.035, stroke);
      final door =
          Path()
            ..moveTo(s * 0.43, s * 0.86)
            ..lineTo(s * 0.43, s * 0.70)
            ..arcToPoint(
              Offset(s * 0.57, s * 0.70),
              radius: Radius.circular(s * 0.07),
              clockwise: true,
            )
            ..lineTo(s * 0.57, s * 0.86);
      canvas.drawPath(door, stroke);
      canvas.drawLine(
        Offset(s * 0.10, s * 0.86),
        Offset(s * 0.90, s * 0.86),
        stroke,
      );
      return;
    }

    final front = Rect.fromLTWH(s * 0.14, s * 0.36, s * 0.48, s * 0.48);
    final top =
        Path()
          ..moveTo(s * 0.14, s * 0.36)
          ..lineTo(s * 0.32, s * 0.18)
          ..lineTo(s * 0.80, s * 0.18)
          ..lineTo(s * 0.62, s * 0.36)
          ..close();
    final side =
        Path()
          ..moveTo(s * 0.62, s * 0.36)
          ..lineTo(s * 0.80, s * 0.18)
          ..lineTo(s * 0.80, s * 0.66)
          ..lineTo(s * 0.62, s * 0.84)
          ..close();
    canvas.drawRect(front, fill);
    canvas.drawPath(top, fill);
    canvas.drawPath(side, fill);
    canvas.drawRect(front, stroke);
    canvas.drawPath(top, stroke);
    canvas.drawPath(side, stroke);
    canvas.drawLine(
      Offset(s * 0.14, s * 0.48),
      Offset(s * 0.62, s * 0.48),
      stroke,
    );
    canvas.drawLine(
      Offset(s * 0.62, s * 0.48),
      Offset(s * 0.80, s * 0.30),
      stroke,
    );
    final door = Rect.fromLTWH(s * 0.32, s * 0.62, s * 0.12, s * 0.22);
    canvas.drawRect(door, stroke);
  }

  @override
  bool shouldRepaint(covariant _RevelationPainter old) =>
      old.madina != madina || old.color != color;
}

/// The banner that opens a surah: a small revelation mark, the Arabic name,
/// and a medallion holding the number of ayat. The frame is drawn, never
/// borrowed, so it belongs to Alim.
class SuraBanner extends StatelessWidget {
  const SuraBanner({super.key, required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context) {
    final p = QuranPalette.of(context);
    final place = surah.revelation == 'Madina' ? 'Medinan' : 'Meccan';
    return Semantics(
      label:
          'Surah ${surah.name}, ${surah.number}, $place, '
          '${surah.ayat} ayat',
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          painter: _BannerPainter(p),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.bronzeTint,
                    border: Border.all(color: p.faintBronze, width: 0.8),
                  ),
                  child: RevelationGlyph(
                    revelation: surah.revelation,
                    color: p.bronze,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        surah.nameAr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: arabicFamily,
                          fontSize: 23,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: p.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${surah.name} · $place · ${surah.ayat} ayat',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.muted,
                          fontSize: 10.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: p.faintBronze, width: 1),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${surah.ayat}',
                          style: TextStyle(
                            color: p.bronze,
                            fontSize: 12.5,
                            height: 1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'ayat',
                          style: TextStyle(
                            color: p.muted,
                            fontSize: 7.5,
                            height: 1.4,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
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

class _BannerPainter extends CustomPainter {
  _BannerPainter(this.p);

  final QuranPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final line =
        Paint()
          ..color = p.bronze.withValues(alpha: 0.44)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8;
    final faint =
        Paint()
          ..color = p.bronze.withValues(alpha: 0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7;
    canvas.drawRect(
      Rect.fromLTWH(5.5, 5.5, size.width - 11, size.height - 11),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(9.5, 9.5, size.width - 19, size.height - 19),
      faint,
    );
    for (final c in [
      Offset(5.5, 5.5),
      Offset(size.width - 5.5, 5.5),
      Offset(5.5, size.height - 5.5),
      Offset(size.width - 5.5, size.height - 5.5),
    ]) {
      canvas.drawCircle(c, 1.7, Paint()..color = p.bronze);
      canvas.drawCircle(c, 3.4, faint);
    }
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final from =
          center +
          Offset(math.cos(angle), math.sin(angle)) * (size.width / 2 - 14);
      final to =
          center +
          Offset(math.cos(angle), math.sin(angle)) * (size.width / 2 - 8);
      canvas.drawLine(from, to, faint);
    }
    final diamond =
        Paint()
          ..color = p.bronze.withValues(alpha: 0.30)
          ..style = PaintingStyle.fill;
    for (final x in [size.width * 0.18, size.width * 0.82]) {
      final path =
          Path()
            ..moveTo(x, size.height / 2 - 3)
            ..lineTo(x + 3, size.height / 2)
            ..lineTo(x, size.height / 2 + 3)
            ..lineTo(x - 3, size.height / 2)
            ..close();
      canvas.drawPath(path, diamond);
    }
  }

  @override
  bool shouldRepaint(covariant _BannerPainter old) => old.p != p;
}

/// The eight-lobed medallion that carries an ayah number in the reader.
class AyahMedallion extends StatelessWidget {
  const AyahMedallion({
    super.key,
    required this.number,
    this.width = 38,
    this.height = 50,
    this.color,
    this.fill,
  });

  final int number;
  final double width;
  final double height;
  final Color? color;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final p = QuranPalette.of(context);
    final c = color ?? p.bronze;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _MedallionPainter(c, fill ?? p.surface),
        child: Center(
          child: Text(
            '$number',
            style: TextStyle(
              color: c,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _MedallionPainter extends CustomPainter {
  _MedallionPainter(this.color, this.fill);

  final Color color;
  final Color fill;

  Path _lobes(Size size, double inset, double squash) {
    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = size.width / 2 - inset;
    final ry = size.height / 2 - inset;
    for (var i = 0; i < 16; i++) {
      final angle = -math.pi / 2 + i * math.pi / 8;
      final factor = i.isEven ? 1.0 : squash;
      final x = cx + rx * factor * math.cos(angle);
      final y = cy + ry * factor * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outer = _lobes(size, 1.5, 0.76);
    canvas.drawPath(outer, Paint()..color = fill);
    canvas.drawPath(
      outer,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    final inner = _lobes(size, size.width * 0.16, 0.80);
    canvas.drawPath(
      inner,
      Paint()
        ..color = color.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
    final mark =
        Paint()
          ..color = color.withValues(alpha: 0.55)
          ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.03),
      Offset(size.width / 2, size.height * 0.14),
      mark,
    );
    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.86),
      Offset(size.width / 2, size.height * 0.97),
      mark,
    );
  }

  @override
  bool shouldRepaint(covariant _MedallionPainter old) =>
      old.color != color || old.fill != fill;
}

/// The Bismillah line, with two quiet rules on either side.
class QuranBismillah extends StatelessWidget {
  const QuranBismillah({super.key});

  @override
  Widget build(BuildContext context) {
    final p = QuranPalette.of(context);
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          Expanded(child: Divider(color: p.hairlineSoft, thickness: 1)),
          const SizedBox(width: 14),
          Text(
            'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
            style: TextStyle(
              fontFamily: quranFamily,
              fontSize: 21,
              height: 1.4,
              color: p.ink,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Divider(color: p.hairlineSoft, thickness: 1)),
        ],
      ),
    );
  }
}

class QuranPill extends StatelessWidget {
  const QuranPill({super.key, required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = QuranPalette.of(context);
    final c = color ?? p.bronze;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AlimRadius.pill),
        border: Border.all(color: c.withValues(alpha: 0.28), width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: c,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

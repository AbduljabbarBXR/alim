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

/// The single header for a surah: revelation mark, Arabic name, its place and
/// length, and the one control that starts or pauses the recitation.
class SuraBanner extends StatelessWidget {
  const SuraBanner({
    super.key,
    required this.surah,
    this.juz,
    this.page,
    this.onPlay,
    this.playing = false,
    this.loading = false,
  });

  final Surah surah;
  final int? juz;
  final int? page;
  final VoidCallback? onPlay;
  final bool playing;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = QuranPalette.of(context);
    final place = surah.revelation == 'Madina' ? 'Medinan' : 'Meccan';
    final meta = [
      surah.name,
      place,
      '${surah.ayat} ayat',
      if (juz != null) 'Juz $juz',
      if (page != null) 'Page $page',
    ].join(' · ');
    return Semantics(
      label:
          'Surah ${surah.name}, ${surah.number}, $place, '
          '${surah.ayat} ayat',
      child: Container(
        height: 80,
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.bronzeTint,
                border: Border.all(color: p.faintBronze, width: 0.8),
              ),
              child: RevelationGlyph(
                revelation: surah.revelation,
                color: p.bronze,
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
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
                      fontSize: 24,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.muted,
                      fontSize: 10.5,
                      letterSpacing: 0.15,
                    ),
                  ),
                ],
              ),
            ),
            if (onPlay != null) ...[
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: playing ? 'Pause recitation' : 'Listen to surah',
                child: Material(
                  color: p.bronzeTint,
                  shape: CircleBorder(side: BorderSide(color: p.faintBronze)),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onPlay,
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Center(
                        child:
                            loading
                                ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                    color: p.bronze,
                                  ),
                                )
                                : Icon(
                                  playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 27,
                                  color: p.bronze,
                                ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
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

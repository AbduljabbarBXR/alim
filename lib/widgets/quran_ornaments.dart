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

/// The surah band: the surah's number on the left, its Arabic name in a
/// cartouche, and the one control that starts or pauses the recitation.
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
    final meta = '${surah.name} · $place · ${surah.ayat} ayat';
    final details = [
      if (juz != null) 'Juz $juz',
      if (page != null) 'Page $page',
    ].join(' · ');
    final iconColor = p.isDark ? p.bg : p.surface;
    return Semantics(
      label:
          'Surah ${surah.name}, number ${surah.number}, $place, '
          '${surah.ayat} ayat',
      child: Container(
        height: 108,
        width: double.infinity,
        color: p.bg,
        child: CustomPaint(
          painter: _SurahBandPainter(p),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Container(
                  key: const Key('surah-header-number'),
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.surface,
                    border: Border.all(color: p.faintBronze),
                  ),
                  child: Text(
                    '${surah.number}',
                    style: TextStyle(
                      color: p.bronzeDeep,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CustomPaint(
                    painter: _SurahCartouchePainter(p),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 30,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'سُورَةُ ${surah.nameAr}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  fontFamily: arabicFamily,
                                  fontSize: 27,
                                  height: 1.05,
                                  fontWeight: FontWeight.w700,
                                  color: p.ink,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: p.muted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (details.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              details,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: p.muted, fontSize: 9.5),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (onPlay != null) ...[
                  const SizedBox(width: 10),
                  Semantics(
                    button: true,
                    label: playing ? 'Pause recitation' : 'Listen to surah',
                    child: Material(
                      color: p.bronzeDeep,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onPlay,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child:
                                loading
                                    ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: iconColor,
                                      ),
                                    )
                                    : Icon(
                                      playing
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 28,
                                      color: iconColor,
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
        ),
      ),
    );
  }
}

class _SurahBandPainter extends CustomPainter {
  _SurahBandPainter(this.p);

  final QuranPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final line =
        Paint()
          ..color = p.faintBronze
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8;
    canvas.drawLine(const Offset(10, 6), Offset(size.width - 10, 6), line);
    canvas.drawLine(
      Offset(10, size.height - 6),
      Offset(size.width - 10, size.height - 6),
      line,
    );
    final diamond =
        Path()
          ..moveTo(size.width / 2, 2)
          ..lineTo(size.width / 2 + 4, 6)
          ..lineTo(size.width / 2, 10)
          ..lineTo(size.width / 2 - 4, 6)
          ..close();
    canvas.drawPath(diamond, line);
  }

  @override
  bool shouldRepaint(covariant _SurahBandPainter old) => old.p != p;
}

class _SurahCartouchePainter extends CustomPainter {
  _SurahCartouchePainter(this.p);

  final QuranPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = _shape(size, 1);
    canvas.drawPath(shape, Paint()..color = p.surface);
    canvas.drawPath(
      shape,
      Paint()
        ..color = p.faintBronze
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawPath(
      _shape(size, 5),
      Paint()
        ..color = p.bronze.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    final center = size.width / 2;
    for (final y in [0.0, size.height]) {
      final diamond =
          Path()
            ..moveTo(center, y - 3)
            ..lineTo(center + 4, y)
            ..lineTo(center, y + 3)
            ..lineTo(center - 4, y)
            ..close();
      canvas.drawPath(
        diamond,
        Paint()
          ..color = p.bronze
          ..style = PaintingStyle.fill,
      );
    }
  }

  Path _shape(Size size, double inset) {
    final w = size.width;
    final h = size.height;
    const r = 16.0;
    final path = Path();
    path.moveTo(inset + r, inset);
    path.quadraticBezierTo(w / 2, inset - 5, w - inset - r, inset);
    path.quadraticBezierTo(w - inset, h / 2, w - inset - r, h - inset);
    path.quadraticBezierTo(w / 2, h - inset + 5, inset + r, h - inset);
    path.quadraticBezierTo(inset, h / 2, inset + r, inset);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _SurahCartouchePainter old) => old.p != p;
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

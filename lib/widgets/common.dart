import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class AlimCard extends StatelessWidget {
  const AlimCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AlimSpace.md),
    this.onTap,
    this.color,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? AlimColors.card(context),
        borderRadius: BorderRadius.circular(AlimRadius.card),
        border: Border.all(color: border ?? AlimColors.hairlineOf(context)),
      ),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AlimRadius.card),
                onTap: onTap,
                child: content,
              ),
            ),
    );
    return decorated;
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AlimSpace.lg,
        bottom: AlimSpace.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// The eight-point star used for surah numbers, drawn the way it appears on
/// a prayer rug border.
class StarNumber extends StatelessWidget {
  const StarNumber({
    super.key,
    required this.number,
    this.size = 40,
    this.color,
    this.filled = false,
  });

  final int number;
  final double size;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StarPainter(c, filled ? c.withValues(alpha: 0.14) : null),
        child: Center(
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: size * 0.34,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.color, this.fill);

  final Color color;
  final Color? fill;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 1;
    final r2 = r * 0.52;
    for (var i = 0; i < 8; i++) {
      final ang = i * math.pi / 4 - math.pi / 2;
      final rad = i.isEven ? r : r2;
      final p = c + Offset(rad * math.cos(ang), rad * math.sin(ang));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    if (fill != null) {
      canvas.drawPath(path, Paint()..color = fill!);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) =>
      old.color != color || old.fill != fill;
}

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.size,
    required this.child,
    this.color,
    this.stroke = 6,
  });

  final double value;
  final double size;
  final Widget child;
  final Color? color;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: value.clamp(0, 1),
              strokeWidth: stroke,
              strokeCap: StrokeCap.round,
              backgroundColor: AlimColors.hairlineOf(context),
              color: color ?? Theme.of(context).colorScheme.primary,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.arabic,
  });

  final String value;
  final String label;
  final String? arabic;

  @override
  Widget build(BuildContext context) {
    return AlimCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AlimSpace.sm,
        vertical: AlimSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: AlimColors.mutedOf(context),
              fontSize: 12.5,
            ),
          ),
          if (arabic != null) ...[
            const SizedBox(height: AlimSpace.xs),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                arabic!,
                style: TextStyle(
                  fontFamily: arabicFamily,
                  color: AlimColors.gold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyNote extends StatelessWidget {
  const EmptyNote({super.key, required this.text, this.icon = Icons.nights_stay_outlined});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AlimCard(
      padding: const EdgeInsets.all(AlimSpace.xl),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AlimColors.mutedOf(context)),
          const SizedBox(height: AlimSpace.sm),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AlimColors.mutedOf(context),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// A pill showing small facts, used for revelation place, ayah counts, ranks.
class AlimPill extends StatelessWidget {
  const AlimPill({
    super.key,
    required this.label,
    this.color,
    this.icon,
  });

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AlimColors.mutedOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AlimRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: c,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The Bismillah band that opens every surah but the ninth and the first.
class BismillahBand extends StatelessWidget {
  const BismillahBand({super.key});

  @override
  Widget build(BuildContext context) {
    return AlimCard(
      color: AlimColors.goldSoft.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.08 : 1,
      ),
      border: AlimColors.gold.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(AlimSpace.md),
      child: Text(
        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: quranFamily,
          fontSize: 22,
          height: 1.8,
          color: AlimColors.inkOf(context),
        ),
      ),
    );
  }
}

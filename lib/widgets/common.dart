import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// A brief floating line near the top of the screen, used for milestones.
void showAlimToast(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry inserted;
  inserted = OverlayEntry(
    builder:
        (_) => _AlimToast(
          message: message,
          onDone: () {
            if (inserted.mounted) inserted.remove();
            inserted.dispose();
          },
        ),
  );
  overlay.insert(inserted);
}

class _AlimToast extends StatefulWidget {
  const _AlimToast({required this.message, required this.onDone});

  final String message;
  final VoidCallback onDone;

  @override
  State<_AlimToast> createState() => _AlimToastState();
}

class _AlimToastState extends State<_AlimToast> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 12,
      left: 20,
      right: 20,
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: dark ? const Color(0xF215211D) : const Color(0xF7FFFDF8),
              borderRadius: BorderRadius.circular(AlimRadius.card),
              border: Border.all(
                color: AlimColors.gold.withValues(alpha: 0.55),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: AlimColors.gold,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.message,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(AlimRadius.card);
    final fill =
        color ?? (dark ? const Color(0xCC15211D) : const Color(0xE6FFFDF8));
    final rim = border ?? AlimColors.gold.withValues(alpha: dark ? 0.30 : 0.36);
    final content = Padding(padding: padding, child: child);
    final surface = DecoratedBox(
      decoration: BoxDecoration(color: fill, borderRadius: radius),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: dark ? 0.045 : 0.18),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.55],
                  ),
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child:
                onTap == null
                    ? content
                    : InkWell(
                      borderRadius: radius,
                      onTap: onTap,
                      child: content,
                    ),
          ),
        ],
      ),
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: (dark ? Colors.black : AlimColors.leafDeep).withValues(
              alpha: dark ? 0.22 : 0.045,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: rim, width: 1.1),
      ),
      child: ClipRRect(borderRadius: radius, child: surface),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AlimSpace.lg, bottom: AlimSpace.xs),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AlimColors.gold,
                  AlimColors.gold.withValues(alpha: 0.25),
                ],
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontFamily: arabicFamily,
                fontWeight: FontWeight.w700,
                fontSize: 16.5,
                letterSpacing: 0.3,
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
    this.strokeWidth = 1.3,
  });

  final int number;
  final double size;
  final Color? color;
  final bool filled;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StarPainter(
          c,
          filled ? c.withValues(alpha: 0.14) : null,
          strokeWidth,
        ),
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
  _StarPainter(this.color, this.fill, this.strokeWidth);

  final Color color;
  final Color? fill;
  final double strokeWidth;

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
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) =>
      old.color != color || old.fill != fill || old.strokeWidth != strokeWidth;
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
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
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
  const EmptyNote({
    super.key,
    required this.text,
    this.icon = Icons.nights_stay_outlined,
  });

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
            style: TextStyle(color: AlimColors.mutedOf(context), height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// A pill showing small facts, used for revelation place, ayah counts, ranks.
class AlimPill extends StatelessWidget {
  const AlimPill({super.key, required this.label, this.color, this.icon});

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

/// A time picker of Alim's own: every hour 01 to 12, every minute 00 to 59,
/// with a clear morning or evening choice.
Future<TimeOfDay?> showAlimTimePicker(BuildContext context, TimeOfDay initial) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    showDragHandle: true,
    builder: (_) => _AlimTimePickerSheet(initial: initial),
  );
}

class _AlimTimePickerSheet extends StatefulWidget {
  const _AlimTimePickerSheet({required this.initial});

  final TimeOfDay initial;

  @override
  State<_AlimTimePickerSheet> createState() => _AlimTimePickerSheetState();
}

class _AlimTimePickerSheetState extends State<_AlimTimePickerSheet> {
  late int _hour =
      widget.initial.hour % 12 == 0 ? 12 : widget.initial.hour % 12;
  late int _minute = widget.initial.minute;
  late bool _evening = widget.initial.hour >= 12;

  TimeOfDay get _value => TimeOfDay(
    hour: _evening ? (_hour % 12) + 12 : _hour % 12,
    minute: _minute,
  );

  String get _label {
    final hour = _value.hourOfPeriod == 0 ? 12 : _value.hourOfPeriod;
    final part = _value.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:'
        '${_value.minute.toString().padLeft(2, '0')} $part';
  }

  Widget _pickBox(BuildContext context, String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AlimColors.mutedOf(context), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AlimSpace.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AlimRadius.field),
            border: Border.all(color: AlimColors.hairlineOf(context)),
          ),
          child: child,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const itemStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AlimSpace.lg,
          0,
          AlimSpace.lg,
          AlimSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'The hour of the reminder',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AlimSpace.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _pickBox(
                    context,
                    'Hour',
                    DropdownButton<int>(
                      value: _hour,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      menuMaxHeight: 320,
                      items: [
                        for (var h = 1; h <= 12; h++)
                          DropdownMenuItem(
                            value: h,
                            child: Text(
                              h.toString().padLeft(2, '0'),
                              style: itemStyle,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _hour = v ?? _hour),
                    ),
                  ),
                ),
                const SizedBox(width: AlimSpace.sm),
                Expanded(
                  child: _pickBox(
                    context,
                    'Minute',
                    DropdownButton<int>(
                      value: _minute,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      menuMaxHeight: 320,
                      items: [
                        for (var m = 0; m < 60; m++)
                          DropdownMenuItem(
                            value: m,
                            child: Text(
                              m.toString().padLeft(2, '0'),
                              style: itemStyle,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _minute = v ?? _minute),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AlimSpace.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('AM')),
                  ButtonSegment(value: true, label: Text('PM')),
                ],
                selected: {_evening},
                showSelectedIcon: false,
                onSelectionChanged:
                    (choice) => setState(() => _evening = choice.first),
              ),
            ),
            const SizedBox(height: AlimSpace.md),
            Text(
              'Reminder at $_label',
              style: TextStyle(
                color: AlimColors.mutedOf(context),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AlimSpace.md),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_value),
              child: const Text('Set the time'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Alim's palette: deep emerald and warm gold on parchment, with a midnight
/// mode for night reading. Every text colour is chosen to clear 4.5:1 on the
/// surface it sits on.
/// A calm slide between pages, written here so the same motion works on
/// every Flutter version and no bare frame flashes between screens.
class AlimPageTransitions extends PageTransitionsBuilder {
  const AlimPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final entering = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final leaving = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(entering),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.22, 0),
        ).animate(leaving),
        child: child,
      ),
    );
  }
}

class AlimColors {
  const AlimColors._();

  static const leaf = Color(0xFF0E6B52);
  static const leafDeep = Color(0xFF083D2F);
  static const leafSoft = Color(0xFFE3F1EB);
  static const leafTint = Color(0xFFBFE0D4);
  static const gold = Color(0xFFC29A3B);
  static const goldSoft = Color(0xFFF6EBD3);
  static const parchment = Color(0xFFF8F4EA);
  static const surface = Color(0xFFFFFDF8);
  static const ink = Color(0xFF23312B);
  static const muted = Color(0xFF64746D);
  static const hairline = Color(0xFFE3DCCB);
  static const rose = Color(0xFFB2534A);
  static const roseSoft = Color(0xFFF7E4E1);

  // Night
  static const night = Color(0xFF0B1512);
  static const nightSurface = Color(0xFF15211D);
  static const nightInk = Color(0xFFE9F2EE);
  static const nightMuted = Color(0xFF9CB0A8);
  static const nightHairline = Color(0xFF243430);

  static Color card(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? nightSurface : surface;
  static Color bg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? night : parchment;
  static Color inkOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? nightInk : ink;
  static Color mutedOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? nightMuted : muted;
  static Color hairlineOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? nightHairline
          : hairline;
}

class AlimSpace {
  const AlimSpace._();
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const xxl = 40.0;
}

class AlimRadius {
  const AlimRadius._();
  static const card = 20.0;
  static const field = 14.0;
  static const pill = 999.0;
}

class AlimMotion {
  const AlimMotion._();
  static const quick = Duration(milliseconds: 160);
  static const settle = Duration(milliseconds: 420);
  static const ease = Curves.easeOutCubic;
}

/// The app's one font scale for Arabic. AmiriQuran for the mushaf itself,
/// Amiri for names and labels. Both are OFL-licensed and bundled.
const arabicFamily = 'Amiri';
const quranFamily = 'AmiriQuran';

ThemeData buildAlimTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: dark ? const Color(0xFF6FC3A4) : AlimColors.leaf,
    onPrimary: dark ? const Color(0xFF04261C) : Colors.white,
    secondary: dark ? const Color(0xFFE0C176) : AlimColors.gold,
    onSecondary: dark ? const Color(0xFF2A1F05) : Colors.white,
    error: dark ? const Color(0xFFE8A79F) : AlimColors.rose,
    onError: dark ? const Color(0xFF3A100C) : Colors.white,
    surface: dark ? AlimColors.nightSurface : AlimColors.surface,
    onSurface: dark ? AlimColors.nightInk : AlimColors.ink,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    fontFamily: 'Roboto',
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: AlimPageTransitions(),
        TargetPlatform.iOS: AlimPageTransitions(),
      },
    ),
  );

  final muted = dark ? AlimColors.nightMuted : AlimColors.muted;
  final line = AlimColors.gold.withValues(alpha: dark ? 0.24 : 0.30);
  final softLine = AlimColors.gold.withValues(alpha: dark ? 0.14 : 0.18);
  final glass = dark ? const Color(0xC615211D) : const Color(0xDBFFFDF8);

  TextStyle heading(TextStyle? style) => (style ?? const TextStyle()).copyWith(
    fontFamily: arabicFamily,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.25,
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displayLarge: heading(base.textTheme.displayLarge),
      displayMedium: heading(base.textTheme.displayMedium),
      displaySmall: heading(base.textTheme.displaySmall),
      headlineLarge: heading(base.textTheme.headlineLarge),
      headlineMedium: heading(base.textTheme.headlineMedium),
      headlineSmall: heading(base.textTheme.headlineSmall),
      titleLarge: heading(base.textTheme.titleLarge),
      titleMedium: heading(base.textTheme.titleMedium),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: scheme.onSurface,
      shape: Border(bottom: BorderSide(color: softLine, width: 1)),
      titleTextStyle: heading(
        base.textTheme.titleLarge,
      ).copyWith(fontSize: 22, color: scheme.onSurface),
      iconTheme: IconThemeData(
        color: dark ? AlimColors.goldSoft : AlimColors.leafDeep,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      indicatorColor: AlimColors.gold.withValues(alpha: dark ? 0.20 : 0.16),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: AlimColors.gold.withValues(alpha: dark ? 0.30 : 0.35),
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 23,
          color:
              selected
                  ? (dark ? AlimColors.goldSoft : AlimColors.leafDeep)
                  : muted,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: arabicFamily,
          fontSize: 12.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color:
              selected
                  ? (dark ? AlimColors.goldSoft : AlimColors.leafDeep)
                  : muted,
        );
      }),
    ),
    cardTheme: CardThemeData(
      color: glass,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AlimRadius.card),
        side: BorderSide(color: line),
      ),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? const Color(0xF215211D) : const Color(0xF7FFFDF8),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: line),
      ),
      titleTextStyle: heading(
        base.textTheme.titleLarge,
      ).copyWith(color: scheme.onSurface, fontSize: 20),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? const Color(0xF215211D) : const Color(0xF7FFFDF8),
      modalBackgroundColor:
          dark ? const Color(0xF215211D) : const Color(0xF7FFFDF8),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        side: BorderSide(color: line),
      ),
    ),
    dividerTheme: DividerThemeData(color: softLine, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xB315211D) : const Color(0xCCFFFDF8),
      hintStyle: TextStyle(color: muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AlimRadius.field),
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AlimRadius.field),
        borderSide: BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AlimRadius.field),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      labelStyle: TextStyle(color: muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        side: BorderSide(
          color: AlimColors.gold.withValues(alpha: dark ? 0.45 : 0.55),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AlimRadius.field),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        side: BorderSide(color: line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AlimRadius.field),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xF215211D) : AlimColors.ink,
      contentTextStyle: TextStyle(
        color: dark ? AlimColors.nightInk : Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AlimRadius.field),
        side: BorderSide(color: softLine),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: muted,
      indicatorColor: AlimColors.gold,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: dark ? AlimColors.goldSoft : AlimColors.leafDeep,
      textColor: scheme.onSurface,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AlimColors.gold,
      linearTrackColor: softLine,
    ),
  );
}

/// A quiet eight-point star lattice drawn behind headers, the way the tilework
/// of a courtyard wall sits behind everything without ever being the subject.
class StarLattice extends StatelessWidget {
  const StarLattice({super.key, required this.child, this.rows = 3});

  final Widget child;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: _LatticePainter(
        color: (dark ? AlimColors.leafTint : AlimColors.leaf).withValues(
          alpha: dark ? 0.06 : 0.045,
        ),
      ),
      child: child,
    );
  }
}

class _LatticePainter extends CustomPainter {
  _LatticePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;
    const step = 64.0;
    const r = 30.0;
    const r2 = 15.0;
    for (var y = 0.0; y < size.height + step; y += step) {
      for (var x = 0.0; x < size.width + step; x += step) {
        final path = Path();
        for (var i = 0; i < 8; i++) {
          final ang = i * math.pi / 4;
          final rad = i.isEven ? r : r2;
          final px = x + rad * math.cos(ang);
          final py = y + rad * math.sin(ang);
          if (i == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LatticePainter oldDelegate) =>
      oldDelegate.color != color;
}

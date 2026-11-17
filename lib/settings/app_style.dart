import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_settings.dart';

/// The app's looks, the same five as the home-screen widgets and with the
/// same colours (android/tools/widget_*.py). Plain is the seeded indigo
/// theme and follows Light / Dark / Black; the others are one fixed look each.
const appStyles = [WidgetStyle.plain, WidgetStyle.leather, WidgetStyle.coins, WidgetStyle.lcd, WidgetStyle.receipt];

/// Money in and money out, per style. LCD has one ink, so its amounts lean
/// on + and the legend. Every text pair is held to 4.5:1 by a test.
class StyleColors extends ThemeExtension<StyleColors> {
  const StyleColors({required this.income, required this.expense});

  final Color income;
  final Color expense;

  @override
  StyleColors copyWith({Color? income, Color? expense}) => StyleColors(income: income ?? this.income, expense: expense ?? this.expense);

  @override
  StyleColors lerp(StyleColors? other, double t) =>
      other == null ? this : StyleColors(income: Color.lerp(income, other.income, t)!, expense: Color.lerp(expense, other.expense, t)!);
}

extension StyleColorsOf on ThemeData {
  // Falls back to Plain's, for widgets built outside the app's theme (tests).
  Color get income => (extension<StyleColors>() ?? styleColors(WidgetStyle.plain, brightness)).income;
  Color get expense => (extension<StyleColors>() ?? styleColors(WidgetStyle.plain, brightness)).expense;
}

// LCD's console, round the screen.
const _plastic = Color(0xFFC8C4BA), _bezel = Color(0xFF4A4A58);

/// The colour scheme of a fixed style; null for Plain, which is seeded.
ColorScheme? styleScheme(WidgetStyle style) => switch (style) {
      WidgetStyle.leather => const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFFF4F1EA),
          onPrimary: Color(0xFF1B1A19),
          primaryContainer: Color(0xFF2E2B28),
          onPrimaryContainer: Color(0xFFF4F1EA),
          secondary: Color(0xFFB3ADA3),
          onSecondary: Color(0xFF1B1A19),
          secondaryContainer: Color(0xFF2E2B28),
          onSecondaryContainer: Color(0xFFF4F1EA),
          tertiary: Color(0xFFAFD8A8),
          onTertiary: Color(0xFF1B1A19),
          error: Color(0xFFE8A79E),
          onError: Color(0xFF1B1A19),
          errorContainer: Color(0xFF4A2622),
          onErrorContainer: Color(0xFFF6D9D4),
          surface: Color(0xFF121110),
          onSurface: Color(0xFFF4F1EA),
          onSurfaceVariant: Color(0xFFB3ADA3),
          outline: Color(0xFF9E978C),
          outlineVariant: Color(0xFF3A3632),
          surfaceContainerLowest: Color(0xFF0D0C0C),
          surfaceContainerLow: Color(0xFF1B1A19),
          surfaceContainer: Color(0xFF1B1A19),
          surfaceContainerHigh: Color(0xFF2E2B28),
          surfaceContainerHighest: Color(0xFF36322E),
          inverseSurface: Color(0xFFF4F1EA),
          onInverseSurface: Color(0xFF1B1A19),
          inversePrimary: Color(0xFF5D574E),
          surfaceTint: Colors.transparent,
        ),
      WidgetStyle.coins => const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF7A4E0C),
          onPrimary: Color(0xFFFFFFFF),
          primaryContainer: Color(0xFFF2B632),
          onPrimaryContainer: Color(0xFF2B2118),
          secondary: Color(0xFF6B5A45),
          onSecondary: Color(0xFFFFF8E8),
          secondaryContainer: Color(0xFFF2B632),
          onSecondaryContainer: Color(0xFF2B2118),
          tertiary: Color(0xFF3B6B1F),
          onTertiary: Color(0xFFFFFFFF),
          error: Color(0xFFA63D17),
          onError: Color(0xFFFFFFFF),
          errorContainer: Color(0xFFF6D2C2),
          onErrorContainer: Color(0xFF5A1E08),
          surface: Color(0xFFFFF8E8),
          onSurface: Color(0xFF2B2118),
          onSurfaceVariant: Color(0xFF6B5A45),
          outline: Color(0xFF6B5A45),
          outlineVariant: Color(0xFFE6D4A8),
          surfaceContainerLowest: Color(0xFFFFFFFF),
          surfaceContainerLow: Color(0xFFF5EAD0),
          surfaceContainer: Color(0xFFF5EAD0),
          surfaceContainerHigh: Color(0xFFEFE0BC),
          surfaceContainerHighest: Color(0xFFE6D4A8),
          inverseSurface: Color(0xFF2B2118),
          onInverseSurface: Color(0xFFF5EAD0),
          inversePrimary: Color(0xFFF2B632),
          surfaceTint: Colors.transparent,
        ),
      WidgetStyle.lcd => const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF0F380F),
          onPrimary: Color(0xFF9BBC0F),
          primaryContainer: Color(0xFF0F380F),
          onPrimaryContainer: Color(0xFF9BBC0F),
          secondary: Color(0xFF306230),
          onSecondary: Color(0xFF9BBC0F),
          secondaryContainer: Color(0xFF0F380F),
          onSecondaryContainer: Color(0xFF9BBC0F),
          tertiary: Color(0xFF0F380F),
          onTertiary: Color(0xFF9BBC0F),
          // The one non-green: a warning must still look like one. Dark
          // enough for 4.5:1 on the cards.
          error: Color(0xFF5C150C),
          onError: Color(0xFF9BBC0F),
          errorContainer: Color(0xFF8BAC0F),
          onErrorContainer: Color(0xFF5C150C),
          surface: Color(0xFF9BBC0F),
          onSurface: Color(0xFF0F380F),
          // One ink: the screen's mid green is too faint for text.
          onSurfaceVariant: Color(0xFF0F380F),
          outline: Color(0xFF0F380F),
          outlineVariant: Color(0xFF306230),
          surfaceContainerLowest: Color(0xFF9BBC0F),
          surfaceContainerLow: Color(0xFF8BAC0F),
          surfaceContainer: Color(0xFF8BAC0F),
          surfaceContainerHigh: Color(0xFF8BAC0F),
          surfaceContainerHighest: Color(0xFF7E9E0E),
          inverseSurface: Color(0xFF0F380F),
          onInverseSurface: Color(0xFF9BBC0F),
          inversePrimary: Color(0xFF9BBC0F),
          surfaceTint: Colors.transparent,
        ),
      WidgetStyle.receipt => const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF1F1D1A),
          onPrimary: Color(0xFFF3EEE4),
          primaryContainer: Color(0xFFE4DDCF),
          onPrimaryContainer: Color(0xFF1F1D1A),
          secondary: Color(0xFF57524A),
          onSecondary: Color(0xFFF3EEE4),
          secondaryContainer: Color(0xFF1F1D1A),
          onSecondaryContainer: Color(0xFFF3EEE4),
          tertiary: Color(0xFF1F1D1A),
          onTertiary: Color(0xFFF3EEE4),
          error: Color(0xFFB3261E),
          onError: Color(0xFFFFFFFF),
          errorContainer: Color(0xFFF6D6D2),
          onErrorContainer: Color(0xFF5C1310),
          surface: Color(0xFFE4DDCF),
          onSurface: Color(0xFF1F1D1A),
          onSurfaceVariant: Color(0xFF57524A),
          outline: Color(0xFF57524A),
          outlineVariant: Color(0xFFB3ADA3),
          surfaceContainerLowest: Color(0xFFFFFFFF),
          surfaceContainerLow: Color(0xFFF3EEE4),
          surfaceContainer: Color(0xFFF3EEE4),
          surfaceContainerHigh: Color(0xFFF3EEE4),
          surfaceContainerHighest: Color(0xFFD9D1C1),
          inverseSurface: Color(0xFF1F1D1A),
          onInverseSurface: Color(0xFFF3EEE4),
          inversePrimary: Color(0xFFE4DDCF),
          surfaceTint: Colors.transparent,
        ),
      WidgetStyle.plain => null,
    };

StyleColors styleColors(WidgetStyle style, [Brightness brightness = Brightness.light]) => switch (style) {
      WidgetStyle.leather => const StyleColors(income: Color(0xFFAFD8A8), expense: Color(0xFFE8A79E)),
      WidgetStyle.coins => const StyleColors(income: Color(0xFF3B6B1F), expense: Color(0xFFA63D17)),
      // Expense in the bezel's grey-violet: 3:1 for chart marks, and a hue apart from the ink.
      WidgetStyle.lcd => const StyleColors(income: Color(0xFF0F380F), expense: Color(0xFF4A4A58)),
      // Till receipts print the minus lines in red.
      WidgetStyle.receipt => const StyleColors(income: Color(0xFF1F1D1A), expense: Color(0xFFB3261E)),
      // Light needs deeper shades for 4.5:1 on its pale cards; dark keeps the bright ones.
      WidgetStyle.plain => brightness == Brightness.light
          ? const StyleColors(income: Color(0xFF1B6E35), expense: Color(0xFFD32F2F))
          : const StyleColors(income: Colors.green, expense: Colors.redAccent),
    };

/// Each style's card: Leather is stitched, Coins pressed in at the bottom,
/// LCD a ruled box, Receipt torn off the roll.
ShapeBorder? styleCardShape(WidgetStyle style) => switch (style) {
      WidgetStyle.leather => const _StitchedBorder(),
      WidgetStyle.coins => const _PressedBorder(),
      WidgetStyle.lcd => const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4)), side: BorderSide(color: Color(0xFF0F380F), width: 2)),
      WidgetStyle.receipt => const _TornBorder(),
      WidgetStyle.plain => null,
    };

class _StitchedBorder extends RoundedRectangleBorder {
  const _StitchedBorder() : super(borderRadius: const BorderRadius.all(Radius.circular(20)));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..color = const Color(0xFF5D574E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final path = Path()..addRRect(borderRadius.resolve(textDirection).toRRect(rect).deflate(6));
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), paint);
      }
    }
  }
}

class _PressedBorder extends RoundedRectangleBorder {
  const _PressedBorder() : super(borderRadius: const BorderRadius.all(Radius.circular(20)));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    canvas.save();
    canvas.clipRRect(borderRadius.resolve(textDirection).toRRect(rect));
    canvas.drawRect(Rect.fromLTRB(rect.left, rect.bottom - 5, rect.right, rect.bottom), Paint()..color = const Color(0xFFE6D4A8));
    canvas.restore();
  }
}

/// Paper with rounded top corners and a torn, saw-tooth bottom edge.
class _TornBorder extends ShapeBorder {
  const _TornBorder();

  static const _tooth = 12.0, _depth = 6.0, _corner = 6.0;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final path = Path()
      ..moveTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top + _corner)
      ..arcToPoint(Offset(rect.left + _corner, rect.top), radius: const Radius.circular(_corner))
      ..lineTo(rect.right - _corner, rect.top)
      ..arcToPoint(Offset(rect.right, rect.top + _corner), radius: const Radius.circular(_corner))
      ..lineTo(rect.right, rect.bottom);
    // Teeth from right to left, each dipping up from the bottom edge.
    for (var x = rect.right; x > rect.left; x -= _tooth) {
      path
        ..lineTo(math.max(x - _tooth / 2, rect.left), rect.bottom - _depth)
        ..lineTo(math.max(x - _tooth, rect.left), rect.bottom);
    }
    return path..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

/// LCD sits inside the handheld: grey plastic and a dark bezel round the
/// whole app. Every other style passes [child] through.
class StyleFrame extends StatelessWidget {
  const StyleFrame({super.key, required this.style, required this.child});

  final WidgetStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (style != WidgetStyle.lcd) return child;
    final media = MediaQuery.of(context);
    final pad = media.padding;
    // What the frame already adds under the app: the keyboard covers that
    // much less of it.
    final below = pad.bottom + 6 + 14;
    return ColoredBox(
      color: _plastic,
      child: Padding(
        padding: pad + const EdgeInsets.all(6),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: _bezel,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12), bottomLeft: Radius.circular(12), bottomRight: Radius.circular(32)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4), bottomLeft: Radius.circular(4), bottomRight: Radius.circular(22)),
              // The frame already keeps clear of the system bars.
              child: MediaQuery(
                data: media.removePadding(removeTop: true, removeBottom: true, removeLeft: true, removeRight: true).copyWith(
                  viewInsets: media.viewInsets.copyWith(bottom: math.max(0, media.viewInsets.bottom - below)),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three dots of a style's colours: page, card and accent.
class StyleSwatch extends StatelessWidget {
  const StyleSwatch(this.style, {super.key});

  final WidgetStyle style;

  @override
  Widget build(BuildContext context) {
    // Plain shows as it is now: light or dark.
    final dark = switch (AppSettings.theme.value) {
      AppTheme.system => MediaQuery.platformBrightnessOf(context) == Brightness.dark,
      AppTheme.light => false,
      AppTheme.dark || AppTheme.black => true,
    };
    final s = styleScheme(style) ??
        ColorScheme.fromSeed(seedColor: dark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5), brightness: dark ? Brightness.dark : Brightness.light);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final c in [s.surface, s.surfaceContainerLow, s.primaryContainer, styleColors(style).expense])
        Container(
          width: 18,
          height: 18,
          margin: const EdgeInsetsDirectional.only(end: 4),
          decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
        ),
    ]);
  }
}

/// The app's look for [style]; Plain is built by the caller.
ThemeData styledTheme(WidgetStyle style, {required List<String> fontFamilyFallback}) {
  final scheme = styleScheme(style)!;
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    fontFamilyFallback: fontFamilyFallback,
    cardTheme: CardThemeData(color: scheme.surfaceContainerLow, elevation: 0, shape: styleCardShape(style)),
    extensions: [styleColors(style)],
  );
}

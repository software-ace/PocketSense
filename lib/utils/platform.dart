import 'package:flutter/material.dart';

/// Centralized platform + breakpoint helpers so every screen can adapt its
/// layout without repeating the logic.
abstract final class PlatformUi {
  /// Width at or above which we consider the viewport "desktop".
  static const double desktopBreakpoint = 900;

  /// True when the current window is wide enough for a sidebar layout.
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

  /// Horizontal padding that scales with the viewport.
  static double hPadding(BuildContext context) =>
      isDesktop(context) ? 32 : 16;

  /// Max content width on very wide screens (keeps text readable).
  static double maxContentWidth(BuildContext context) =>
      isDesktop(context) ? 1100 : double.infinity;
}

import 'package:flutter/material.dart';

/// Which app is rendering — carries that app's accent seed and drives
/// [AppColorTokens.of]. See `design-system/MASTER.md` §1 for the rationale
/// behind each color.
enum AppBrand { parent, driver, admin, superAdmin }

extension AppBrandSeed on AppBrand {
  Color get seed {
    switch (this) {
      case AppBrand.parent:
        return const Color(0xFF0F6E71); // calm, reassuring teal
      case AppBrand.driver:
        return const Color(0xFF1E5FA8); // high-contrast operational cobalt
      case AppBrand.admin:
        return const Color(0xFF3B4A6B); // professional indigo-slate
      case AppBrand.superAdmin:
        return const Color(0xFFC9A227); // "control tower" gold
    }
  }
}

/// Semantic color tokens shared by every app. Light/dark pairs are chosen
/// independently of each other — dark mode is never a naive inversion of
/// light mode. See `design-system/MASTER.md` §2.
class AppColorTokens {
  const AppColorTokens({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.disabled,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.emergency,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color disabled;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color emergency;

  static const light = AppColorTokens(
    background: Color(0xFFF7F8FB),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    border: Color(0xFFE3E6EC),
    textPrimary: Color(0xFF12161C),
    textSecondary: Color(0xFF4A5160),
    textMuted: Color(0xFF8A90A0),
    disabled: Color(0xFFC7CBD4),
    success: Color(0xFF1E7A4C),
    warning: Color(0xFFA5680A),
    error: Color(0xFFB23B34),
    info: Color(0xFF2C5DA6),
    emergency: Color(0xFFC22A2A),
  );

  static const dark = AppColorTokens(
    background: Color(0xFF0E1116),
    surface: Color(0xFF161A21),
    surfaceElevated: Color(0xFF1D222B),
    border: Color(0xFF2A2F3A),
    textPrimary: Color(0xFFEDEFF3),
    textSecondary: Color(0xFFB7BCC6),
    textMuted: Color(0xFF7C8293),
    disabled: Color(0xFF3A404C),
    success: Color(0xFF5FBF8A),
    warning: Color(0xFFDBA847),
    error: Color(0xFFE2726B),
    info: Color(0xFF7FA6E0),
    emergency: Color(0xFFF0554F),
  );

  static AppColorTokens of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// 4pt spacing scale. See `design-system/MASTER.md` §4.
class AppSpacing {
  AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xl2 = 24.0;
  static const xl3 = 32.0;
  static const xl4 = 40.0;
  static const xl5 = 48.0;
  static const xl6 = 64.0;
}

/// Corner radii. See `design-system/MASTER.md` §5.
class AppRadius {
  AppRadius._();

  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const pill = 999.0;
}

/// Elevation shadows for surfaces that genuinely float above content
/// (dialogs, sheets, popups, snackbars) — never applied to ordinary cards,
/// which stay flat and border-forward. See `design-system/MASTER.md` §6.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> level1(Color ink) => [
    BoxShadow(
      color: ink.withValues(alpha: 0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> level2(Color ink) => [
    BoxShadow(
      color: ink.withValues(alpha: 0.10),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> level3(Color ink) => [
    BoxShadow(
      color: ink.withValues(alpha: 0.14),
      blurRadius: 40,
      offset: const Offset(0, 16),
    ),
  ];
}

/// Motion durations. See `design-system/MASTER.md` §10.
class AppDurations {
  AppDurations._();

  static const pageTransition = Duration(milliseconds: 220);
  static const stateSwitch = Duration(milliseconds: 180);
  static const entrance = Duration(milliseconds: 220);
  static const successPop = Duration(milliseconds: 300);
}

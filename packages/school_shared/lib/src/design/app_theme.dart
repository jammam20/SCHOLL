import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// The semantic color tokens ([AppColorTokens]) exposed through
/// `Theme.of(context)`, so components reach them the idiomatic Flutter way
/// (`Theme.of(context).extension<AppSemanticColors>()!`) instead of every
/// widget re-deriving light/dark branching by hand.
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors(this.tokens);

  final AppColorTokens tokens;

  @override
  AppSemanticColors copyWith({AppColorTokens? tokens}) =>
      AppSemanticColors(tokens ?? this.tokens);

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return t < 0.5 ? this : other;
  }
}

/// Convenience accessor: `context.appColors.success`, etc.
extension AppSemanticColorsX on BuildContext {
  AppColorTokens get appColors =>
      Theme.of(this).extension<AppSemanticColors>()!.tokens;
}

/// Builds the [ThemeData] for one app/brightness/locale combination. This
/// replaces four near-identical hand-copied `theme.dart` files (one per
/// app) with a single shared implementation driven by [AppBrand] — see
/// `design-system/MASTER.md` "Theme architecture". The resulting
/// `ThemeData` keeps the exact shape (field names, component themes) the
/// four apps already relied on; only the values now come from shared
/// tokens instead of four copies of the same numbers.
ThemeData buildAppTheme({
  required AppBrand brand,
  required Brightness brightness,
  required Locale locale,
}) {
  final isDark = brightness == Brightness.dark;
  final seed = brand.seed;
  final tokens = AppColorTokens.of(brightness);
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorSchemeSeed: seed,
  );
  final colors = base.colorScheme;
  final textTheme = AppTypography.textTheme(locale, base.textTheme);

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: tokens.background,
    extensions: [AppSemanticColors(tokens)],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: colors.onSurface,
      titleTextStyle: AppTypography.appBarTitle(locale, colors.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: tokens.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: tokens.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl2,
          vertical: AppSpacing.lg,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl2,
          vertical: AppSpacing.lg,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        side: BorderSide(color: colors.outline),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.55),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xl,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: seed, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: tokens.error, width: 1.4),
      ),
      labelStyle: TextStyle(color: colors.onSurfaceVariant),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      side: BorderSide.none,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
    ),
    dividerTheme: DividerThemeData(color: tokens.border, space: 1),
    tabBarTheme: TabBarThemeData(
      labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13.5,
      ),
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl - 6),
      ),
      elevation: 1,
      extendedTextStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      height: 68,
      backgroundColor: tokens.surface,
      indicatorColor: seed.withValues(alpha: isDark ? 0.28 : 0.14),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11.5,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? colors.onSurface
              : colors.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? seed
              : colors.onSurfaceVariant,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: tokens.surface,
      indicatorColor: seed.withValues(alpha: isDark ? 0.28 : 0.14),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      selectedLabelTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: colors.onSurface,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: colors.onSurfaceVariant,
      ),
      selectedIconTheme: IconThemeData(color: seed),
      unselectedIconTheme: IconThemeData(color: colors.onSurfaceVariant),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? seed : null,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      color: tokens.surfaceElevated,
      elevation: 3,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      backgroundColor: tokens.surfaceElevated,
    ),
    snackBarTheme: SnackBarThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Named type styles shared by every app, so no screen sets a raw
/// `fontSize`/`fontWeight` outside this scale. See
/// `design-system/MASTER.md` §3.
///
/// Latin text uses Plus Jakarta Sans (already the face all four apps used
/// before this pass). Arabic text uses Cairo — Plus Jakarta Sans has no
/// Arabic glyphs, so Arabic previously fell back to whatever font each
/// Android version ships, which reads inconsistently. [textTheme] picks
/// the right family for the active locale automatically.
class AppTypography {
  AppTypography._();

  static bool _isArabic(Locale locale) => locale.languageCode == 'ar';

  static TextTheme _fontFamilyTextTheme(Locale locale, TextTheme base) =>
      _isArabic(locale)
      ? GoogleFonts.cairoTextTheme(base)
      : GoogleFonts.plusJakartaSansTextTheme(base);

  static TextStyle _fontFamilyStyle(Locale locale, TextStyle style) =>
      _isArabic(locale) ? GoogleFonts.cairo(textStyle: style) : GoogleFonts.plusJakartaSans(textStyle: style);

  /// The full [TextTheme] used as `ThemeData.textTheme`, built on top of
  /// [base] (a Material-generated theme for the current [ColorScheme]).
  static TextTheme textTheme(Locale locale, TextTheme base) {
    final withFont = _fontFamilyTextTheme(locale, base);
    return withFont.copyWith(
      headlineMedium: withFont.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 30,
        height: 38 / 30,
      ),
      headlineSmall: withFont.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 24,
        height: 32 / 24,
      ),
      titleLarge: withFont.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        height: 26 / 18,
      ),
      titleMedium: withFont.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        height: 24 / 16,
      ),
      bodyLarge: withFont.bodyLarge?.copyWith(fontSize: 14, height: 22 / 14),
      bodyMedium: withFont.bodyMedium?.copyWith(fontSize: 14, height: 22 / 14),
      bodySmall: withFont.bodySmall?.copyWith(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: withFont.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        height: 20 / 15,
      ),
      labelSmall: withFont.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 11,
        height: 16 / 11,
        letterSpacing: 0.4,
      ),
    );
  }

  /// The app-bar title style — kept as a named helper since it's set
  /// outside `textTheme` on `AppBarTheme.titleTextStyle`.
  static TextStyle appBarTitle(Locale locale, Color color) => _fontFamilyStyle(
    locale,
    TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
  );
}

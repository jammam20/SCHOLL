import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Named type styles shared by every app, so no screen sets a raw
/// `fontSize`/`fontWeight` outside this scale. See
/// `design-system/MASTER.md` §3.
///
/// Latin headings use **Lexend**, body text uses **Source Sans 3** — this
/// pairing came out of a real UI/UX Pro Max design-system query for this
/// product ("school transportation operations safety trust enterprise
/// console"), whose own catalog describes it as "corporate, trustworthy,
/// accessible, readable" and best suited to "Enterprise, government,
/// healthcare, finance, accessibility-focused" products — an unusually
/// good fit for a school-safety platform, and Lexend specifically is
/// designed to reduce visual stress in reading, which matters for a
/// status/emergency-heavy UI. This replaces the previous single-family
/// choice (Plus Jakarta Sans for everything). Arabic text keeps **Cairo**
/// — the query tool has no Arabic-typography data, so that choice (a
/// dedicated Arabic-optimized face, chosen in the prior phase because
/// Latin-only fonts have no Arabic glyphs and fall back inconsistently)
/// stands on its own merits. [textTheme] picks the right family for the
/// active locale automatically.
class AppTypography {
  AppTypography._();

  static bool _isArabic(Locale locale) => locale.languageCode == 'ar';

  /// Heading-role styles (display/headline/title) get [_headingFont];
  /// body/label-role styles get [_bodyFont]. Both collapse to Cairo for
  /// Arabic, which doesn't have a heading/body pairing in the query tool's
  /// data and reads better as one consistent face.
  static TextStyle _headingFont(Locale locale, TextStyle style) =>
      _isArabic(locale)
      ? GoogleFonts.cairo(textStyle: style)
      : GoogleFonts.lexend(textStyle: style);

  static TextStyle _bodyFont(Locale locale, TextStyle style) =>
      _isArabic(locale)
      ? GoogleFonts.cairo(textStyle: style)
      : GoogleFonts.sourceSans3(textStyle: style);

  /// The full [TextTheme] used as `ThemeData.textTheme`, built on top of
  /// [base] (a Material-generated theme for the current [ColorScheme]).
  static TextTheme textTheme(Locale locale, TextTheme base) {
    TextStyle heading(TextStyle? s) => _headingFont(locale, s ?? const TextStyle());
    TextStyle body(TextStyle? s) => _bodyFont(locale, s ?? const TextStyle());

    return base.copyWith(
      displayLarge: heading(base.displayLarge),
      displayMedium: heading(base.displayMedium),
      displaySmall: heading(base.displaySmall),
      headlineLarge: heading(base.headlineLarge),
      headlineMedium: heading(base.headlineMedium).copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 30,
        height: 38 / 30,
      ),
      headlineSmall: heading(base.headlineSmall).copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 24,
        height: 32 / 24,
      ),
      titleLarge: heading(base.titleLarge).copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        height: 26 / 18,
      ),
      titleMedium: heading(base.titleMedium).copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        height: 24 / 16,
      ),
      titleSmall: heading(base.titleSmall),
      bodyLarge: body(base.bodyLarge).copyWith(fontSize: 14, height: 22 / 14),
      bodyMedium: body(base.bodyMedium).copyWith(fontSize: 14, height: 22 / 14),
      bodySmall: body(base.bodySmall).copyWith(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: body(base.labelLarge).copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        height: 20 / 15,
      ),
      labelMedium: body(base.labelMedium),
      labelSmall: body(base.labelSmall).copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 11,
        height: 16 / 11,
        letterSpacing: 0.4,
      ),
    );
  }

  /// The app-bar title style — kept as a named helper since it's set
  /// outside `textTheme` on `AppBarTheme.titleTextStyle`.
  static TextStyle appBarTitle(Locale locale, Color color) => _headingFont(
    locale,
    TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
  );
}

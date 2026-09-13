import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'app_settings.theme_mode';
const _localeKey = 'app_settings.locale';

/// The languages the apps ship in, in the order the picker lists them.
///
/// [nativeName] is deliberately the language's own name rather than its
/// English name — someone who has accidentally left the app in a language
/// they can't read needs to recognise their own language in the list to
/// get back out of it.
enum AppLanguage {
  arabic('ar', 'العربية'),
  english('en', 'English'),
  french('fr', 'Français'),
  spanish('es', 'Español');

  const AppLanguage(this.code, this.nativeName);

  final String code;
  final String nativeName;

  Locale get locale => Locale(code);

  /// The entry for [code], or English when the code isn't one we ship —
  /// covers a corrupted preference or a locale saved by an older build.
  static AppLanguage fromCode(String? code) => values.firstWhere(
    (language) => language.code == code,
    orElse: () => AppLanguage.english,
  );
}

/// Every locale the apps support, for `MaterialApp.supportedLocales`.
final supportedLocales = List<Locale>.unmodifiable(
  AppLanguage.values.map((language) => language.locale),
);

/// Session-level dark/light + language switches, now persisted across
/// restarts via `shared_preferences` (previously each app's own copy of
/// this class reset to light/English every cold start — see
/// `design-system/MASTER.md` "Theme architecture"). Call [AppSettings.load]
/// once at startup, before `runApp`, to restore the saved values.
///
/// This one implementation replaces four byte-identical copies that used
/// to live in each app's own `lib/app/app_settings.dart`.
class AppSettings {
  AppSettings._();

  static final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
  static final locale = ValueNotifier<Locale>(const Locale('en'));

  /// Restoring a saved theme/language is a nice-to-have, never something
  /// worth blocking app startup over — in a storage-partitioned or
  /// otherwise restricted browser context (e.g. an embedded preview pane),
  /// `SharedPreferences.getInstance()` on web can hang instead of failing
  /// fast, since it waits on a JS promise that may never settle rather
  /// than throwing synchronously. A short timeout plus a catch-all means a
  /// blocked/unavailable storage backend degrades to "start with defaults"
  /// instead of an app that never renders its first frame.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      final savedTheme = prefs.getString(_themeModeKey);
      if (savedTheme == 'dark') themeMode.value = ThemeMode.dark;
      final savedLocale = prefs.getString(_localeKey);
      if (savedLocale != null) {
        locale.value = AppLanguage.fromCode(savedLocale).locale;
      }
    } catch (_) {
      // Defaults (light, English) already set above — nothing else to do.
    }
    // Outside the try: whatever language we ended up on (restored or the
    // default), dates must format in it.
    await _applyDateLocale(language);
  }

  static Future<void> toggleTheme() async {
    themeMode.value = themeMode.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      await prefs.setString(
        _themeModeKey,
        themeMode.value == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (_) {
      // The toggle itself already applied above; only persistence failed.
    }
  }

  /// Switches the whole app to [language] and remembers it.
  ///
  /// Replaces the old binary en<->ar `toggleLocale()`: with four languages
  /// there is no "the other one" to flip to, so the caller now names the
  /// language it wants (see `showLanguagePickerSheet`).
  ///
  /// [onChanged] runs after the switch has applied and been persisted
  /// locally — the apps pass a callback that mirrors the choice into
  /// Firestore, which is what lets Cloud Functions send push notifications
  /// in the language the user actually reads (the preference is otherwise
  /// device-local and never reaches the server).
  static Future<void> setLocale(
    AppLanguage language, {
    Future<void> Function(AppLanguage language)? onChanged,
  }) async {
    await _applyDateLocale(language);
    if (locale.value.languageCode != language.code) {
      locale.value = language.locale;
    }
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      await prefs.setString(_localeKey, language.code);
    } catch (_) {
      // The switch itself already applied above; only persistence failed.
    }
    if (onChanged != null) {
      try {
        await onChanged(language);
      } catch (_) {
        // Mirroring to the server is best-effort — a failed write must not
        // undo a language change the user can already see on screen.
      }
    }
  }

  /// The language currently in effect.
  static AppLanguage get language =>
      AppLanguage.fromCode(locale.value.languageCode);

  /// Points `package:intl` at [language] so every bare `DateFormat(...)`
  /// formats in it.
  ///
  /// There are ~45 `DateFormat` call sites across the apps and not one of
  /// them passes a locale, so before this they all rendered English month
  /// names, weekday names and AM/PM even with the app in Arabic. Setting
  /// the default globally fixes all of them at once, and keeps working for
  /// any call site added later — the alternative was threading a locale
  /// argument through 45 places and relying on nobody forgetting the 46th.
  static Future<void> _applyDateLocale(AppLanguage language) async {
    Intl.defaultLocale = language.code;
    try {
      await initializeDateFormatting(language.code);
    } catch (_) {
      // Date symbols for a locale we ship should always load; if they
      // somehow don't, intl falls back to its built-in defaults rather
      // than throwing out of app startup or a language switch.
    }
  }
}

/// A string in each language the apps ship, picked by whichever locale is
/// active — e.g. `S('Sign in', 'تسجيل الدخول', fr: 'Se connecter',
/// es: 'Iniciar sesión').of(context)`. Deliberately inline rather than a
/// central keyed lookup table: keeping every form of a string next to each
/// other at the call site makes it obvious what's translated and what
/// isn't yet.
///
/// [fr] and [es] are optional so the two languages could be filled in
/// incrementally without breaking the build on the ~1,600 existing call
/// sites, each falling back to [en] until translated. `tool/check_translations.dart`
/// reports how many are still missing, so "we translated everything" is a
/// number that can be checked rather than a claim — the fallback must never
/// become a quiet way to ship English.
class S {
  const S(this.en, this.ar, {this.fr, this.es});

  final String en;
  final String ar;
  final String? fr;
  final String? es;

  String of(BuildContext context) =>
      forLocale(Localizations.localeOf(context));

  /// The form for [locale] — split out from [of] so code with no
  /// `BuildContext` (a bloc mapping an error, a notification renderer) can
  /// resolve the same string against `AppSettings.locale`.
  String forLocale(Locale locale) => switch (locale.languageCode) {
    'ar' => ar,
    'fr' => fr ?? en,
    'es' => es ?? en,
    _ => en,
  };
}

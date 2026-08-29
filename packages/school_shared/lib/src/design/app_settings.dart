import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'app_settings.theme_mode';
const _localeKey = 'app_settings.locale';

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
      if (savedLocale == 'ar') locale.value = const Locale('ar');
    } catch (_) {
      // Defaults (light, English) already set above — nothing else to do.
    }
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

  static Future<void> toggleLocale() async {
    locale.value = locale.value.languageCode == 'ar'
        ? const Locale('en')
        : const Locale('ar');
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      await prefs.setString(_localeKey, locale.value.languageCode);
    } catch (_) {
      // The toggle itself already applied above; only persistence failed.
    }
  }
}

/// A string with an English and Arabic form, picked by whichever locale is
/// active — e.g. `S('Sign in', 'تسجيل الدخول').of(context)`. Deliberately
/// inline rather than a central keyed lookup table: keeping each string's
/// two forms next to each other at the call site makes it obvious what's
/// translated and what isn't yet.
class S {
  const S(this.en, this.ar);

  final String en;
  final String ar;

  String of(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
}

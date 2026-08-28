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

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeModeKey);
    if (savedTheme == 'dark') themeMode.value = ThemeMode.dark;
    final savedLocale = prefs.getString(_localeKey);
    if (savedLocale == 'ar') locale.value = const Locale('ar');
  }

  static Future<void> toggleTheme() async {
    themeMode.value = themeMode.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _themeModeKey,
      themeMode.value == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  static Future<void> toggleLocale() async {
    locale.value = locale.value.languageCode == 'ar'
        ? const Locale('en')
        : const Locale('ar');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.value.languageCode);
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

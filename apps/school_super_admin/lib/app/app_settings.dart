import 'package:flutter/material.dart';

/// Session-level dark/light + language switches. Simple ValueNotifiers
/// (not persisted across restarts) rather than a full settings-storage
/// layer — enough to let anyone toggle both live from the app bar.
class AppSettings {
  AppSettings._();

  static final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
  static final locale = ValueNotifier<Locale>(const Locale('en'));

  static void toggleTheme() {
    themeMode.value = themeMode.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  static void toggleLocale() {
    locale.value = locale.value.languageCode == 'ar'
        ? const Locale('en')
        : const Locale('ar');
  }
}

/// A string with an English and Arabic form, picked by whichever locale is
/// active — e.g. `S('Sign in', 'تسجيل الدخول').of(context)`. Deliberately
/// inline rather than a central keyed lookup table: only the main chrome
/// (app bars, tab labels, the login screen) is translated this pass, and
/// keeping each string's two forms next to each other at the call site
/// makes it obvious what's covered and what isn't yet.
class S {
  const S(this.en, this.ar);

  final String en;
  final String ar;

  String of(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
}

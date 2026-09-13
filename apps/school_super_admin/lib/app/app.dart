import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/auth/data/firebase_auth_repository.dart';
import '../features/auth/presentation/cubit/auth_cubit.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../firebase_options.dart';
import 'app_settings.dart';
import 'theme.dart';

class SuperAdminApp extends StatelessWidget {
  const SuperAdminApp({super.key});

  static Future<void> initializeFirebase() =>
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => AuthCubit(FirebaseAuthRepository())..start(),
    child: ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.themeMode,
      builder: (context, themeMode, _) => ValueListenableBuilder<Locale>(
        valueListenable: AppSettings.locale,
        builder: (context, locale, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Jammam Super Admin',
          supportedLocales: supportedLocales,
          locale: locale,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: themeMode,
          theme: buildAppTheme(
            brand: AppBrand.superAdmin,
            brightness: Brightness.light,
            locale: locale,
          ),
          darkTheme: buildAppTheme(
            brand: AppBrand.superAdmin,
            brightness: Brightness.dark,
            locale: locale,
          ),
          home: const OnboardingGate(child: LoginPage()),
        ),
      ),
    ),
  );
}

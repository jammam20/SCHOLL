import 'package:flutter/widgets.dart';
import 'package:school_shared/school_shared.dart';

/// Turns an [AuthFailureCode] into something the system admin can read, in
/// the app's language.
///
/// The cubit used to build these sentences itself, in English, and the
/// login page rendered them verbatim — so the one screen an admin cannot
/// get past was also the one screen that ignored their language. A cubit
/// has no `BuildContext` and therefore no locale, so it now emits the
/// failure's identity and the words are chosen here. Mirrors the driver
/// app's `authFailureMessage` (see
/// `apps/school_driver/lib/features/auth/presentation/auth_failure_message.dart`);
/// this app has no self-registration, so there is no `fromRegistration`
/// flag to thread through.
String authFailureMessage(AuthFailureCode code, BuildContext context) {
  return switch (code) {
    AuthFailureCode.invalidCredentials => const S(
      'Email or password is incorrect.',
      'الإيميل أو الباسورد غلط.',
      fr: 'E-mail ou mot de passe incorrect.',
      es: 'Correo electrónico o contraseña incorrectos.',
    ).of(context),
    AuthFailureCode.emailAlreadyInUse => const S(
      'An account already exists with this email.',
      'في حساب موجود بالفعل بالإيميل ده.',
      fr: 'Un compte existe déjà avec cette adresse e-mail.',
      es: 'Ya existe una cuenta con este correo electrónico.',
    ).of(context),
    AuthFailureCode.weakPassword => const S(
      'Choose a stronger password — at least 6 characters.',
      'اختار باسورد أقوى — 6 حروف على الأقل.',
      fr: 'Choisissez un mot de passe plus robuste — au moins 6 caractères.',
      es: 'Elige una contraseña más segura — al menos 6 caracteres.',
    ).of(context),
    AuthFailureCode.invalidEmail => const S(
      "That email address doesn't look right.",
      'الإيميل ده شكله مش مظبوط.',
      fr: 'Cette adresse e-mail ne semble pas valide.',
      es: 'Esa dirección de correo electrónico no parece válida.',
    ).of(context),
    AuthFailureCode.tooManyRequests => const S(
      'Too many attempts. Wait a moment and try again.',
      'محاولات كتير. استنى شوية وجرب تاني.',
      fr: 'Trop de tentatives. Patientez un instant, puis réessayez.',
      es: 'Demasiados intentos. Espera un momento y vuelve a intentarlo.',
    ).of(context),
    AuthFailureCode.network => const S(
      'No connection. Check your internet and try again.',
      'مفيش اتصال. راجع النت وجرب تاني.',
      fr: 'Aucune connexion. Vérifiez votre connexion internet et réessayez.',
      es:
          'Sin conexión. Comprueba tu conexión a internet e inténtalo de '
          'nuevo.',
    ).of(context),
    AuthFailureCode.disabled => const S(
      'This administrator account is not active.',
      'حساب المشرف ده مش نشط.',
      fr: "Ce compte administrateur n'est pas actif.",
      es: 'Esta cuenta de administrador no está activa.',
    ).of(context),
    AuthFailureCode.pending => const S(
      'This account is still awaiting approval.',
      'الحساب ده لسه مستني موافقة.',
      fr: "Ce compte est encore en attente d'approbation.",
      es: 'Esta cuenta todavía está pendiente de aprobación.',
    ).of(context),
    AuthFailureCode.unauthorized => const S(
      'This account does not have system admin access.',
      'الحساب ده معهوش صلاحية مشرف عام.',
      fr: "Ce compte n'a pas d'accès administrateur système.",
      es: 'Esta cuenta no tiene acceso de administrador del sistema.',
    ).of(context),
    AuthFailureCode.unknown => const S(
      'Unable to load your account.',
      'معرفناش نحمّل حسابك.',
      fr: 'Impossible de charger votre compte.',
      es: 'No se pudo cargar tu cuenta.',
    ).of(context),
  };
}

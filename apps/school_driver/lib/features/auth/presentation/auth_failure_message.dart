import 'package:flutter/widgets.dart';
import 'package:school_shared/school_shared.dart';

/// Turns an [AuthFailureCode] into something the driver can read, in the
/// app's language.
///
/// The cubit used to build these sentences itself, in English, and the
/// login page rendered them verbatim — so the one screen a driver cannot
/// get past was also the one screen that ignored their language. A cubit
/// has no `BuildContext` and therefore no locale, so it now emits the
/// failure's identity and the words are chosen here.
///
/// [fromRegistration] distinguishes the two paths that share a code:
/// `invalidCredentials` while signing in means the email or password is
/// wrong, but the same code coming out of a failed registration means the
/// account couldn't be created at all.
String authFailureMessage(
  AuthFailureCode code,
  BuildContext context, {
  bool fromRegistration = false,
}) {
  if (fromRegistration && code != AuthFailureCode.emailAlreadyInUse) {
    return const S(
      'We could not create your account.',
      'معرفناش نعمل حسابك.',
      fr: "Nous n'avons pas pu créer votre compte.",
      es: 'No pudimos crear tu cuenta.',
    ).of(context);
  }

  return switch (code) {
    AuthFailureCode.invalidCredentials => const S(
      'Email or password is incorrect.',
      'الإيميل أو الباسورد غلط.',
      fr: 'E-mail ou mot de passe incorrect.',
      es: 'Correo o contraseña incorrectos.',
    ).of(context),
    AuthFailureCode.emailAlreadyInUse => const S(
      'An account already exists with this email.',
      'في حساب موجود بالفعل بالإيميل ده.',
      fr: 'Un compte existe déjà avec cet e-mail.',
      es: 'Ya existe una cuenta con este correo.',
    ).of(context),
    AuthFailureCode.weakPassword => const S(
      'Choose a stronger password — at least 6 characters.',
      'اختار باسورد أقوى — 6 حروف على الأقل.',
      fr: 'Choisissez un mot de passe plus fort — au moins 6 caractères.',
      es: 'Elige una contraseña más segura — al menos 6 caracteres.',
    ).of(context),
    AuthFailureCode.invalidEmail => const S(
      "That email address doesn't look right.",
      'الإيميل ده شكله مش مظبوط.',
      fr: "Cette adresse e-mail semble incorrecte.",
      es: 'Esa dirección de correo no parece correcta.',
    ).of(context),
    AuthFailureCode.tooManyRequests => const S(
      'Too many attempts. Wait a moment and try again.',
      'محاولات كتير. استنى شوية وجرب تاني.',
      fr: 'Trop de tentatives. Patientez un instant et réessayez.',
      es: 'Demasiados intentos. Espera un momento e inténtalo de nuevo.',
    ).of(context),
    AuthFailureCode.network => const S(
      'No connection. Check your internet and try again.',
      'مفيش اتصال. راجع النت وجرب تاني.',
      fr: 'Aucune connexion. Vérifiez votre accès Internet et réessayez.',
      es: 'Sin conexión. Comprueba tu Internet e inténtalo de nuevo.',
    ).of(context),
    AuthFailureCode.disabled => const S(
      'Your driver account is not active.',
      'حساب السواق بتاعك مش نشط.',
      fr: "Votre compte chauffeur n'est pas actif.",
      es: 'Tu cuenta de conductor no está activa.',
    ).of(context),
    AuthFailureCode.pending => const S(
      'Your account is still waiting for school approval.',
      'حسابك لسه مستني موافقة المدرسة.',
      fr: "Votre compte attend encore l'approbation de l'école.",
      es: 'Tu cuenta aún espera la aprobación de la escuela.',
    ).of(context),
    AuthFailureCode.unauthorized => const S(
      'This account is not a driver account.',
      'الحساب ده مش حساب سواق.',
      fr: "Ce compte n'est pas un compte chauffeur.",
      es: 'Esta cuenta no es una cuenta de conductor.',
    ).of(context),
    AuthFailureCode.unknown => const S(
      'Unable to load your account.',
      'معرفناش نحمّل حسابك.',
      fr: 'Impossible de charger votre compte.',
      es: 'No se pudo cargar tu cuenta.',
    ).of(context),
  };
}

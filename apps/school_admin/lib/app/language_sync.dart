import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_shared/school_shared.dart';

/// Mirrors the signed-in user's chosen language into Firestore so the
/// backend can read it.
///
/// The preference otherwise lives only in `shared_preferences` on the
/// device, which means Cloud Functions — the thing that actually sends push
/// notifications — has no way to know which language to write them in. That
/// is why notifications arrived in English no matter what the app was set
/// to. Storing it server-side is what makes a localized push possible at
/// all.
///
/// Written as `notificationPrefs.language` rather than a top-level field on
/// purpose: firestore.rules restricts a user's own update to
/// `hasOnly(['notificationPrefs', 'name', 'updatedAt'])`, so nesting it
/// needs no rules change, and the send path already loads the whole user
/// document (`tokensAndPrefsForUser` in functions/src/index.ts) so reading
/// it costs no extra document read.
///
/// Kept per-app rather than in school_shared because that package is
/// deliberately Firebase-free — it owns pure models and design, the apps
/// own their own Firestore I/O (the same reason each app has its own
/// `audit_log_repository.dart`).
class LanguageSync {
  const LanguageSync._();

  /// Saves [language] for the current user. A no-op when signed out: the
  /// picker is also reachable from login/onboarding, where there is no
  /// account to attach the preference to yet — [syncCurrent] carries that
  /// choice over once they sign in.
  static Future<void> save(AppLanguage language) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'notificationPrefs': {'language': language.code},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Pushes whatever language the app is currently in — called after
  /// sign-in so a language picked on the login screen still reaches the
  /// server.
  static Future<void> syncCurrent() => save(AppSettings.language);
}

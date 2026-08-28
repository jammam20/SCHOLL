import '../models/auth_session_state.dart';

/// Framework- and provider-agnostic authentication contract.
///
/// Implementations are responsible for combining Firebase Authentication
/// state with the authoritative `schools/{schoolId}/members/{uid}`
/// membership record to produce an [AuthSessionState]. This interface does
/// not depend on `firebase_auth`, `cloud_firestore`, `flutter_bloc`, or any
/// other framework/provider, so it can be implemented and consumed without
/// coupling the domain layer to a specific technology.
abstract interface class AuthRepository {
  /// Emits the current [AuthSessionState] and every subsequent change to it.
  ///
  /// Implementations should combine the underlying authentication provider's
  /// session stream with the corresponding school membership record so that
  /// membership changes (approval, suspension, role changes) are reflected
  /// without requiring the caller to re-authenticate.
  Stream<AuthSessionState> watchSession();

  /// Signs in with an email and password.
  ///
  /// On failure, implementations should throw an
  /// `AuthFailure` (see `package:school_shared/school_shared.dart`) rather
  /// than a provider-specific exception.
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Signs the current user out.
  Future<void> signOut();
}

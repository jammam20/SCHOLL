import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_shared/school_shared.dart';

/// Turns whatever this layer threw into the framework-agnostic
/// [AuthFailureCode] the rest of the app reasons about.
///
/// The point is language, not tidiness: everything below the widget tree
/// runs without a BuildContext, so any sentence built here could only ever
/// be in one language — and it used to be, since the cubit put English
/// straight into `AuthSignedOut.message` and login_page.dart rendered it
/// verbatim, leaving a French or Spanish system admin reading English at
/// the one screen they cannot get past. A code carries the *identity* of
/// the failure up to the presentation layer, which has a context and can
/// pick the right words (see `authFailureMessage`).
AuthFailureCode authFailureCodeFor(Object error) {
  if (error is AuthFailure) return error.code;
  if (error is! FirebaseAuthException) return AuthFailureCode.unknown;
  return switch (error.code) {
    // Recent firebase_auth collapses wrong-password/user-not-found into
    // 'invalid-credential' to avoid leaking which of the two it was; older
    // versions (and the emulator) still send the split codes, so both
    // spellings are handled.
    'invalid-credential' ||
    'invalid-login-credentials' ||
    'wrong-password' ||
    'user-not-found' => AuthFailureCode.invalidCredentials,
    'invalid-email' => AuthFailureCode.invalidEmail,
    'too-many-requests' => AuthFailureCode.tooManyRequests,
    'network-request-failed' => AuthFailureCode.network,
    'user-disabled' => AuthFailureCode.disabled,
    _ => AuthFailureCode.unknown,
  };
}

/// A signed-in system admin — this app has exactly one kind of user.
class SuperAdminProfile {
  const SuperAdminProfile({required this.uid, required this.name});
  final String uid;
  final String name;
}

/// Sign-in only — deliberately no self-registration here. A system admin
/// is the platform owner's own top-level role, so `systemAdmins/{uid}`
/// documents are created by hand (Firebase Console, or by an existing
/// system admin) rather than through a self-serve request like
/// parent/driver/school-admin accounts use.
class FirebaseAuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Emits `null` (signed out, or signed in but not a system admin) or a
  /// [SuperAdminProfile].
  Stream<SuperAdminProfile?> watchUser() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream<SuperAdminProfile?>.value(null);

      return _firestore
          .collection('systemAdmins')
          .doc(user.uid)
          .snapshots()
          .map((snapshot) {
            if (!snapshot.exists || snapshot.data()?['isActive'] != true) {
              return null;
            }
            return SuperAdminProfile(
              uid: user.uid,
              name: snapshot.data()?['name'] as String? ?? 'Super Admin',
            );
          });
    });
  }

  Future<void> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // A one-shot mirror of watchUser()'s logic (.get() instead of
  // .snapshots()), used right after a successful sign-in — see the driver/
  // parent/admin apps' identical fetchCurrentUser for why sign-in can't
  // rely on the background authStateChanges() listener alone (it left the
  // sign-in button stuck on "Please wait…" until a manual page refresh).
  Future<SuperAdminProfile?> fetchCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _firestore.collection('systemAdmins').doc(user.uid).get();
    if (!snapshot.exists || snapshot.data()?['isActive'] != true) return null;

    return SuperAdminProfile(
      uid: user.uid,
      name: snapshot.data()?['name'] as String? ?? 'Super Admin',
    );
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }
}

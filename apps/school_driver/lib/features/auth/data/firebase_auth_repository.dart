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
/// verbatim, leaving a French or Spanish driver reading English at the one
/// screen they cannot get past. A code carries the *identity* of the
/// failure up to the presentation layer, which has a context and can pick
/// the right words (see `authFailureMessage`).
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
    'email-already-in-use' => AuthFailureCode.emailAlreadyInUse,
    'weak-password' => AuthFailureCode.weakPassword,
    'too-many-requests' => AuthFailureCode.tooManyRequests,
    'network-request-failed' => AuthFailureCode.network,
    'user-disabled' => AuthFailureCode.disabled,
    _ => AuthFailureCode.unknown,
  };
}

class FirebaseAuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<AppUser?> watchUser() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream<AppUser?>.value(null);
      }

      return _firestore
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .asyncExpand((userSnapshot) {
        if (!userSnapshot.exists) {
          return Stream<AppUser?>.value(null);
        }

        final userData = userSnapshot.data();

        if (userData == null) {
          return Stream<AppUser?>.value(null);
        }

        final schoolId = userData['schoolId'] as String?;

        if (schoolId == null || schoolId.isEmpty) {
          return Stream<AppUser?>.value(null);
        }

        return _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('members')
            .doc(user.uid)
            .snapshots()
            .map((memberSnapshot) {
          if (!memberSnapshot.exists) {
            return null;
          }

          final memberData = memberSnapshot.data();

          if (memberData == null) {
            return null;
          }

          final member = SchoolMember.fromMap(
            user.uid,
            memberData,
          );

          return AppUser.fromMap(
            user.uid,
            {
              ...userData,
              'schoolId': member.schoolId,
              'role': member.role.value,
              'isActive': member.isActive,
              'approved':
              member.status == MembershipStatus.approved,
              'membershipStatus':
              member.status.value,
              'rejectionReason': member.rejectionReason,
            },
          );
        });
      });
    });
  }

  Future<void> signIn(
      String email,
      String password,
      ) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // A one-shot mirror of watchUser()'s logic (.get() instead of
  // .snapshots()), used right after a successful sign-in. Sign-in used to
  // rely entirely on watchUser()'s already-running authStateChanges()
  // listener noticing the new session and re-emitting — reasonable in
  // theory, but on Flutter web that broadcast stream doesn't reliably
  // re-fire for a listener that was already subscribed while signed out,
  // which left the sign-in button stuck on "Please wait…" until a manual
  // page refresh (a fresh start() call reads the already-authenticated
  // user immediately). Fetching directly sidesteps that stream entirely
  // for this one transition; the background subscription still keeps
  // handling everything else (sign-out, an admin later disabling the
  // account, etc).
  Future<AppUser?> fetchCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final userSnapshot = await _firestore.collection('users').doc(user.uid).get();
    if (!userSnapshot.exists) return null;
    final userData = userSnapshot.data();
    if (userData == null) return null;

    final schoolId = userData['schoolId'] as String?;
    if (schoolId == null || schoolId.isEmpty) return null;

    final memberSnapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('members')
        .doc(user.uid)
        .get();
    if (!memberSnapshot.exists) return null;
    final memberData = memberSnapshot.data();
    if (memberData == null) return null;

    final member = SchoolMember.fromMap(user.uid, memberData);
    return AppUser.fromMap(user.uid, {
      ...userData,
      'schoolId': member.schoolId,
      'role': member.role.value,
      'isActive': member.isActive,
      'approved': member.status == MembershipStatus.approved,
      'membershipStatus': member.status.value,
      'rejectionReason': member.rejectionReason,
    });
  }

  // Writes the new driver's `users/{uid}` and `schools/{id}/members/{uid}`
  // documents directly (firestore.rules scopes `create` on both to a
  // strictly pending, self-owned request — see isPendingSelfServeDoc)
  // instead of going through a Cloud Function callable, so signing up
  // doesn't require the project to be on Firebase's paid Blaze plan. An
  // admin then approves the pending driver from the admin app's Drivers
  // tab.
  //
  // Returns the resulting AppUser directly rather than making the caller
  // wait on watchUser()'s realtime listener to notice the new docs — that's
  // `authStateChanges()` firing, then a `users/{uid}` snapshot arriving,
  // then (once schoolId is known) a *second*, freshly-subscribed
  // `members/{uid}` snapshot arriving — several sequential round trips
  // that otherwise leave "Please wait…" on screen far longer than the
  // write itself took.
  Future<AppUser> registerDriver({
    required String name,
    required String email,
    required String password,
    required String schoolCode,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user!.uid;

    try {
      final code = schoolCode.trim().toUpperCase();
      final codeSnapshot = await _firestore
          .collection('schoolJoinCodes')
          .doc(code)
          .get();
      final codeData = codeSnapshot.data();
      // Both school-code problems reach the driver as the same typed
      // failure, because the same thing is true of both from where they
      // stand: the code they typed did not get them in, and their school is
      // who can fix it. The differing [AuthFailure.message] is for logs
      // only — it is never shown (see AuthFailure's own doc comment).
      if (!codeSnapshot.exists || codeData?['active'] != true) {
        throw const AuthFailure(
          AuthFailureCode.invalidCredentials,
          message: 'School code is invalid.',
        );
      }

      final schoolId = codeData?['schoolId'] as String?;
      if (schoolId == null || schoolId.isEmpty) {
        throw const AuthFailure(
          AuthFailureCode.invalidCredentials,
          message: 'School code is not configured correctly.',
        );
      }

      // Not read directly here: a brand-new registrant isn't a member of
      // any school yet, so `schools/{schoolId}` is off-limits to them under
      // firestore.rules (`allow read: if isActiveMember(...)`). The same
      // isActive check happens instead inside the `members/{uid}` create
      // rule below, via a rule-internal get() that isn't subject to that
      // read restriction — if the school isn't active, the batch commit
      // itself fails with permission-denied.
      final trimmedName = name.trim();
      final now = FieldValue.serverTimestamp();
      final batch = _firestore.batch();
      batch.set(_firestore.collection('users').doc(uid), {
        'uid': uid,
        'name': trimmedName,
        'email': credential.user?.email,
        'role': 'driver',
        'schoolId': schoolId,
        'isActive': true,
        'approved': false,
        'membershipStatus': 'pending',
        'createdAt': now,
        'updatedAt': now,
      });
      batch.set(
        _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('members')
            .doc(uid),
        {
          'uid': uid,
          'schoolId': schoolId,
          'role': 'driver',
          'status': 'pending',
          'isActive': true,
          'displayName': trimmedName,
          'email': credential.user?.email,
          'createdAt': now,
          'updatedAt': now,
        },
      );
      await batch.commit();

      return AppUser(
        uid: uid,
        schoolId: schoolId,
        role: UserRole.driver,
        isActive: true,
        approved: false,
        membershipStatus: MembershipStatus.pending,
        name: trimmedName,
        email: credential.user?.email ?? email.trim(),
      );
    } catch (_) {
      await credential.user?.delete();
      rethrow;
    }
  }

  Future<void> signOut() {
    return _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }
}
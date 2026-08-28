import 'package:equatable/equatable.dart';

import 'app_user.dart';
import 'auth_failure.dart';

/// The framework-agnostic authentication/session state for an application.
///
/// This models the combination of Firebase Authentication state and the
/// authoritative `schools/{schoolId}/members/{uid}` membership authorization
/// already established in the existing architecture. It does not depend on
/// any state-management framework (no BLoC/Cubit, no Riverpod) and does not
/// depend on any authentication provider implementation.
sealed class AuthSessionState extends Equatable {
  const AuthSessionState();
}

/// The session has not been determined yet (for example, before the first
/// Firebase Auth/membership snapshot has been observed).
class AuthSessionUnknown extends AuthSessionState {
  const AuthSessionUnknown();

  @override
  List<Object?> get props => [];
}

/// An authentication operation (sign in, sign out, session resolution) is in
/// progress.
class AuthSessionLoading extends AuthSessionState {
  const AuthSessionLoading();

  @override
  List<Object?> get props => [];
}

/// No Firebase Authentication user is currently signed in.
class AuthSessionUnauthenticated extends AuthSessionState {
  const AuthSessionUnauthenticated();

  @override
  List<Object?> get props => [];
}

/// A Firebase Authentication user is signed in and their
/// `schools/{schoolId}/members/{uid}` membership authorizes access to the
/// current application ([AppUser.canAccessApp] is `true`).
class AuthSessionAuthenticated extends AuthSessionState {
  const AuthSessionAuthenticated(this.user);

  final AppUser user;

  @override
  List<Object?> get props => [user];
}

/// A Firebase Authentication user is signed in, but their school membership
/// is still awaiting approval.
class AuthSessionPending extends AuthSessionState {
  const AuthSessionPending(this.user);

  final AppUser user;

  @override
  List<Object?> get props => [user];
}

/// A Firebase Authentication user is signed in, but their school membership
/// has been deactivated/suspended (`isActive == false`).
class AuthSessionDisabled extends AuthSessionState {
  const AuthSessionDisabled(this.user);

  final AppUser user;

  @override
  List<Object?> get props => [user];
}

/// A Firebase Authentication user is signed in, but they are not authorized
/// to use the current application (for example, the wrong role for this
/// app). [user] is included when a profile could be resolved.
class AuthSessionUnauthorized extends AuthSessionState {
  const AuthSessionUnauthorized({this.user});

  final AppUser? user;

  @override
  List<Object?> get props => [user];
}

/// Resolving or mutating the session failed.
class AuthSessionError extends AuthSessionState {
  const AuthSessionError(this.failure);

  final AuthFailure failure;

  @override
  List<Object?> get props => [failure];
}

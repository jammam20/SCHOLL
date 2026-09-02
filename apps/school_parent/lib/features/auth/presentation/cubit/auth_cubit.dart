import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:school_shared/school_shared.dart';

import '../../../../app/analytics.dart';
import '../../data/firebase_auth_repository.dart';

sealed class AuthState {
  const AuthState();
}

final class AuthLoading extends AuthState {
  const AuthLoading();
}

final class AuthSignedOut extends AuthState {
  const AuthSignedOut({this.message});

  final String? message;
}

final class AuthPendingApproval extends AuthState {
  const AuthPendingApproval(this.user);

  final AppUser user;
}

final class AuthRejected extends AuthState {
  const AuthRejected(this.user);

  final AppUser user;
}

final class AuthDisabled extends AuthState {
  const AuthDisabled(this.user);

  final AppUser user;
}

final class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.user);

  final AppUser user;
}

// Pure role/status decision logic, extracted so the cross-app role boundary
// (only 'parent' may reach AuthSignedIn here) is unit-testable without
// mocking Firebase. Mirrors the equivalent function in the admin and
// driver apps' own auth_cubit.dart — each app enforces its own allowed
// role(s) independently.
AuthState resolveAuthState(AppUser user) {
  // A signed-in Firebase user with an approved, active school membership in
  // a *different* role (driver/admin/staff) must never reach AuthSignedIn
  // here, or AuthPage would hand them the parent home shell.
  if (user.role != UserRole.parent) {
    return const AuthSignedOut(message: 'This account is not a parent account.');
  }

  if (user.isDisabled) return AuthDisabled(user);
  if (user.isRejected) return AuthRejected(user);
  if (user.isPending) return AuthPendingApproval(user);

  if (!user.canAccessApp) {
    return const AuthSignedOut(message: 'Your account is not authorized.');
  }

  return AuthSignedIn(user);
}

class AuthCubit extends Cubit<AuthState> with WidgetsBindingObserver {
  AuthCubit(this._repository) : super(const AuthLoading());

  final FirebaseAuthRepository _repository;

  StreamSubscription<AppUser?>? _subscription;

  void start() {
    _subscription ??= _repository.watchCurrentUser().listen(
      _handleUser,
      onError: (error, stackTrace) {
        emit(
          const AuthSignedOut(
            message: 'Unable to load your account.',
          ),
        );
      },
    );
    WidgetsBinding.instance.addObserver(this);
  }

  // Browsers throttle JS timers heavily for background tabs, which can
  // leave an already-open Firestore snapshot listener's callback queued
  // for a long time even though the underlying document changed instantly
  // — e.g. the school approved something for this account from a different
  // tab while this one sat in the background. Re-fetching once the tab
  // regains focus means the app catches up the moment someone actually
  // looks at it again, instead of requiring a manual page reload to
  // "notice" the change.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshNow();
  }

  Future<void> _refreshNow() async {
    try {
      _handleUser(await _repository.fetchCurrentUser());
    } catch (_) {
      // Best-effort nudge — the live subscription above remains the actual
      // source of truth, so a failed refresh here isn't itself an error.
    }
  }

  void _handleUser(AppUser? user) {
    if (user == null) {
      emit(const AuthSignedOut());
      return;
    }

    emit(resolveAuthState(user));
  }

  Future<void> signIn(
      String email,
      String password,
      ) async {
    emit(const AuthLoading());

    try {
      await _repository.signIn(
        email: email,
        password: password,
      );
      // Resolve state from a direct fetch rather than waiting on the
      // background subscription to react — see fetchCurrentUser's doc
      // comment for why that stream can't be trusted for this transition.
      _handleUser(await _repository.fetchCurrentUser());
      // Logged only for an actual credential-based sign-in, not the
      // background session-restore path in _handleUser/start().
      if (state is AuthSignedIn) AppAnalytics.logLoginSuccess();
    } catch (_) {
      emit(
        const AuthSignedOut(
          message: 'Email or password is incorrect.',
        ),
      );
    }
  }

  Future<void> register(
      String name,
      String email,
      String password,
      String schoolCode,
      ) async {
    emit(const AuthLoading());

    try {
      // A brand-new registration is always pending — emit that immediately
      // with the user data we already have, instead of waiting on
      // watchCurrentUser()'s realtime listener to round-trip back down
      // (see registerParent's doc comment). That listener is still the
      // live subscription driving this cubit going forward — this is just
      // a fast first paint.
      final user = await _repository.registerParent(
        name: name,
        email: email,
        password: password,
        schoolCode: schoolCode,
      );
      emit(AuthPendingApproval(user));
    } catch (_) {
      emit(
        const AuthSignedOut(
          message: 'We could not create your account.',
        ),
      );
    }
  }

  Future<void> signOut() => _repository.signOut();

  @override
  Future<void> close() async {
    WidgetsBinding.instance.removeObserver(this);
    await _subscription?.cancel();
    return super.close();
  }
}
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

final class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.user);

  final AppUser user;
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

class AuthCubit extends Cubit<AuthState> with WidgetsBindingObserver {
  AuthCubit(this._repository) : super(const AuthLoading());

  final FirebaseAuthRepository _repository;

  StreamSubscription<AppUser?>? _subscription;

  void start() {
    _subscription ??= _repository.watchUser().listen(
      _handleUser,
      onError: (error, stackTrace) {
        emit(const AuthSignedOut(message: 'Unable to load your account.'));
      },
    );
    WidgetsBinding.instance.addObserver(this);
  }

  // Browsers throttle JS timers heavily for background tabs, which can
  // leave an already-open Firestore snapshot listener's callback queued
  // for a long time even though the underlying document changed instantly
  // — e.g. a system admin approved this account from a different tab while
  // this one sat in the background. Re-fetching once the tab regains focus
  // means the app catches up the moment someone actually looks at it again,
  // instead of requiring a manual page reload to "notice" the change.
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

    // This app serves two roles: full admins, and `staff` — a read-only
    // operational role that gets its own StaffHomePage (see LoginPage,
    // which branches on AuthSignedIn.user.role). Staff are never treated
    // as a subset of admin: they go through the same approval gates below
    // and are handed a shell with no write actions at all, mirroring how
    // firestore.rules spells out every staff grant separately rather than
    // folding it into isSchoolAdmin.
    if (user.role != UserRole.admin && user.role != UserRole.staff) {
      emit(
        const AuthSignedOut(
          message:
              'This account is not an administrator or school staff account.',
        ),
      );
      return;
    }

    if (user.isDisabled) {
      emit(AuthDisabled(user));
      return;
    }

    if (user.isRejected) {
      emit(AuthRejected(user));
      return;
    }

    if (user.isPending) {
      emit(AuthPendingApproval(user));
      return;
    }

    if (!user.canAccessApp) {
      emit(
        const AuthSignedOut(message: 'Your account is not active.'),
      );
      return;
    }

    emit(AuthSignedIn(user));
  }

  Future<void> signIn(String email, String password) async {
    emit(const AuthLoading());

    try {
      await _repository.signIn(email, password);
      // Resolve state from a direct fetch rather than waiting on the
      // background subscription to react — see fetchCurrentUser's doc
      // comment for why that stream can't be trusted for this transition.
      _handleUser(await _repository.fetchCurrentUser());
      // Logged only for an actual credential-based sign-in, not the
      // background session-restore path in _handleUser/start().
      if (state is AuthSignedIn) AppAnalytics.logLoginSuccess();
    } catch (_) {
      emit(const AuthSignedOut(message: 'Email or password is incorrect.'));
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
      // watchUser()'s realtime listener to round-trip back down (see
      // registerAdmin's doc comment).
      final user = await _repository.registerAdmin(
        name: name,
        email: email,
        password: password,
        schoolCode: schoolCode,
      );
      emit(AuthPendingApproval(user));
    } catch (_) {
      emit(const AuthSignedOut(message: 'We could not create your account.'));
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

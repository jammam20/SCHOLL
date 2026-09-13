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
  const AuthSignedOut({this.code, this.fromRegistration = false});

  /// Why the driver isn't signed in, or null for the ordinary signed-out
  /// state (a cold start, an explicit sign-out) that needs no explanation.
  ///
  /// This used to be a `String? message` holding an English sentence built
  /// right here — which login_page.dart then rendered verbatim, so a driver
  /// running the app in Arabic, French or Spanish read English at the one
  /// screen they cannot get past. A cubit has no BuildContext and therefore
  /// no language; carrying the failure's *identity* instead lets the
  /// presentation layer say it in the driver's own (see
  /// `authFailureMessage`).
  final AuthFailureCode? code;

  /// Whether [code] came from a registration attempt rather than a sign-in.
  ///
  /// [AuthFailureCode] has no value for "that school code is wrong", so
  /// registration reports it as [AuthFailureCode.invalidCredentials] — the
  /// same code a bad email/password produces when signing in. This flag is
  /// what keeps the two apart at render time. It lives on the state rather
  /// than being read from the form's own registering/signing-in toggle
  /// because that toggle can flip while an error is still on screen, which
  /// would silently rewrite the message under a failure it doesn't describe.
  final bool fromRegistration;
}

final class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.user);

  final AppUser user;
}

final class AuthPendingApproval extends AuthState {
  const AuthPendingApproval(this.user);

  final AppUser user;
}

final class AuthDisabled extends AuthState {
  const AuthDisabled(this.user);

  final AppUser user;
}

final class AuthRejected extends AuthState {
  const AuthRejected(this.user);

  final AppUser user;
}

// Pure role/status decision logic, extracted so the cross-app role boundary
// (only 'driver' may reach AuthSignedIn here) is unit-testable without
// mocking Firebase. Mirrors the equivalent function in the admin and
// parent apps' own auth_cubit.dart — each app enforces its own allowed
// role(s) independently.
AuthState resolveAuthState(AppUser user) {
  if (user.role != UserRole.driver) {
    return const AuthSignedOut(code: AuthFailureCode.unauthorized);
  }

  // See the admin app's resolveAuthState for why order matters here: every
  // real reject/register write ties isActive to the approved status, so the
  // broader isDisabled check must run after isRejected/isPending or it
  // always wins first and those two states become unreachable.
  if (user.isRejected) return AuthRejected(user);
  if (user.isPending) return AuthPendingApproval(user);
  if (user.isDisabled) return AuthDisabled(user);

  if (!user.canAccessApp) {
    return const AuthSignedOut(code: AuthFailureCode.disabled);
  }

  return AuthSignedIn(user);
}

class AuthCubit extends Cubit<AuthState> with WidgetsBindingObserver {
  AuthCubit(this._repository) : super(const AuthLoading());

  final FirebaseAuthRepository _repository;

  StreamSubscription<AppUser?>? _subscription;
  Timer? _pendingApprovalPoll;

  void start() {
    _subscription ??= _repository.watchUser().listen(
      _handleUser,
      onError: (error, stackTrace) {
        emit(AuthSignedOut(code: authFailureCodeFor(error)));
      },
    );
    WidgetsBinding.instance.addObserver(this);
  }

  // Browsers throttle JS timers heavily for background tabs, which can
  // leave an already-open Firestore snapshot listener's callback queued
  // for a long time even though the underlying document changed instantly
  // — e.g. an admin approved this account from a different tab while this
  // one sat in the background. Re-fetching once the tab regains focus means
  // the app catches up the moment someone actually looks at it again,
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
      _setPendingApprovalPolling(false);
      emit(const AuthSignedOut());
      return;
    }

    final next = resolveAuthState(user);
    _setPendingApprovalPolling(next is AuthPendingApproval);
    emit(next);
  }

  // Firestore's realtime listener is the source of truth, but on some
  // devices (seen on Android emulators, not just the browser-tab-throttling
  // case _refreshNow's own doc comment covers) that listener's underlying
  // stream can go quietly stale while the app sits on this screen — the
  // admin's approval write never arrives until something else (a full app
  // restart) opens a fresh connection. A driver stuck on "waiting for
  // approval" has no way to trigger that themselves, so this polls the same
  // one-shot fetch every 15s for as long as they're on this screen — a
  // cheap self-heal that needs no manual restart, on top of (not instead
  // of) the live subscription and the resume-nudge above.
  void _setPendingApprovalPolling(bool shouldPoll) {
    if (shouldPoll == (_pendingApprovalPoll != null)) return;
    if (shouldPoll) {
      _pendingApprovalPoll = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _refreshNow(),
      );
    } else {
      _pendingApprovalPoll?.cancel();
      _pendingApprovalPoll = null;
    }
  }

  Future<void> signIn(
      String email,
      String password,
      ) async {
    emit(const AuthLoading());

    try {
      await _repository.signIn(
        email,
        password,
      );
      // Resolve state from a direct fetch rather than waiting on the
      // background subscription to react — see fetchCurrentUser's doc
      // comment for why that stream can't be trusted for this transition.
      _handleUser(await _repository.fetchCurrentUser());
      // Logged only for an actual credential-based sign-in, not the
      // background session-restore path in _handleUser/start() — Analytics
      // already has its own automatic session_start event for that.
      if (state is AuthSignedIn) AppAnalytics.logLoginSuccess();
    } catch (error) {
      emit(AuthSignedOut(code: authFailureCodeFor(error)));
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
      // registerDriver's doc comment).
      final user = await _repository.registerDriver(
        name: name,
        email: email,
        password: password,
        schoolCode: schoolCode,
      );
      _setPendingApprovalPolling(true);
      emit(AuthPendingApproval(user));
    } catch (error) {
      emit(
        AuthSignedOut(
          code: authFailureCodeFor(error),
          fromRegistration: true,
        ),
      );
    }
  }

  Future<void> signOut() => _repository.signOut();

  @override
  Future<void> close() async {
    WidgetsBinding.instance.removeObserver(this);
    _pendingApprovalPoll?.cancel();
    await _subscription?.cancel();
    return super.close();
  }
}
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:school_shared/school_shared.dart';

import '../../data/firebase_auth_repository.dart';

sealed class AuthState {
  const AuthState();
}

final class AuthLoading extends AuthState {
  const AuthLoading();
}

final class AuthSignedOut extends AuthState {
  const AuthSignedOut({this.code});

  /// Why the admin isn't signed in, or null for the ordinary signed-out
  /// state (a cold start, an explicit sign-out) that needs no explanation.
  ///
  /// This used to be a `String? message` holding an English sentence built
  /// right here — which login_page.dart then rendered verbatim, so a system
  /// admin running the app in Arabic, French or Spanish read English at the
  /// one screen they cannot get past. A cubit has no BuildContext and
  /// therefore no language; carrying the failure's *identity* instead lets
  /// the presentation layer say it in the admin's own (see
  /// `authFailureMessage`).
  final AuthFailureCode? code;
}

final class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.profile);
  final SuperAdminProfile profile;
}

class AuthCubit extends Cubit<AuthState> with WidgetsBindingObserver {
  AuthCubit(this._repository) : super(const AuthLoading());

  final FirebaseAuthRepository _repository;

  StreamSubscription<SuperAdminProfile?>? _subscription;

  void start() {
    _subscription ??= _repository.watchUser().listen(
      _handleProfile,
      onError: (error, stackTrace) {
        emit(AuthSignedOut(code: authFailureCodeFor(error)));
      },
    );
    WidgetsBinding.instance.addObserver(this);
  }

  void _handleProfile(SuperAdminProfile? profile) {
    if (profile == null) {
      emit(const AuthSignedOut());
    } else {
      emit(AuthSignedIn(profile));
    }
  }

  // Browsers throttle JS timers heavily for background tabs, which can
  // leave an already-open Firestore snapshot listener's callback queued
  // for a long time even though the underlying document changed instantly.
  // Re-fetching once the tab regains focus means the app catches up the
  // moment someone actually looks at it again, instead of requiring a
  // manual page reload to "notice" the change.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshNow();
  }

  Future<void> _refreshNow() async {
    try {
      _handleProfile(await _repository.fetchCurrentUser());
    } catch (_) {
      // Best-effort nudge — the live subscription above remains the actual
      // source of truth, so a failed refresh here isn't itself an error.
    }
  }

  Future<void> signIn(String email, String password) async {
    emit(const AuthLoading());
    try {
      await _repository.signIn(email, password);
      // Resolve state from a direct fetch rather than waiting on the
      // background subscription to react — see fetchCurrentUser's doc
      // comment for why that stream can't be trusted for this transition.
      final profile = await _repository.fetchCurrentUser();
      emit(profile == null ? const AuthSignedOut() : AuthSignedIn(profile));
    } catch (error) {
      emit(AuthSignedOut(code: authFailureCodeFor(error)));
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

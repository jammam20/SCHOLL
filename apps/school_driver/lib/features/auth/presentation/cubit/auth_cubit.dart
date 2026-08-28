import 'dart:async';

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

final class AuthDisabled extends AuthState {
  const AuthDisabled(this.user);

  final AppUser user;
}

final class AuthRejected extends AuthState {
  const AuthRejected(this.user);

  final AppUser user;
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository) : super(const AuthLoading());

  final FirebaseAuthRepository _repository;

  StreamSubscription<AppUser?>? _subscription;

  void start() {
    _subscription ??= _repository.watchUser().listen(
      _handleUser,
      onError: (error, stackTrace) {
        emit(
          const AuthSignedOut(
            message: 'Unable to load your account.',
          ),
        );
      },
    );
  }

  void _handleUser(AppUser? user) {
    if (user == null) {
      emit(const AuthSignedOut());
      return;
    }

    if (user.role != UserRole.driver) {
      emit(
        const AuthSignedOut(
          message: 'This account is not a driver account.',
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
        const AuthSignedOut(
          message: 'Your driver account is not active.',
        ),
      );
      return;
    }

    emit(AuthSignedIn(user));
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
      // watchUser()'s realtime listener to round-trip back down (see
      // registerDriver's doc comment).
      final user = await _repository.registerDriver(
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
    await _subscription?.cancel();
    return super.close();
  }
}
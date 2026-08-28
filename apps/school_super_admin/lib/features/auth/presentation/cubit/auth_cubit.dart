import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

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
  const AuthSignedIn(this.profile);
  final SuperAdminProfile profile;
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository) : super(const AuthLoading());

  final FirebaseAuthRepository _repository;

  StreamSubscription<SuperAdminProfile?>? _subscription;

  void start() {
    _subscription ??= _repository.watchUser().listen(
      (profile) {
        if (profile == null) {
          emit(const AuthSignedOut());
        } else {
          emit(AuthSignedIn(profile));
        }
      },
      onError: (error, stackTrace) {
        emit(const AuthSignedOut(message: 'Unable to load your account.'));
      },
    );
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
    } catch (_) {
      emit(const AuthSignedOut(message: 'Email or password is incorrect.'));
    }
  }

  Future<void> signOut() => _repository.signOut();

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

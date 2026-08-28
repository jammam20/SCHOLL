import 'package:equatable/equatable.dart';

import '../enums/auth_failure_code.dart';

/// A framework-agnostic authentication failure.
///
/// [message] is an optional technical description intended for logging or
/// debugging. It is not localized user-facing copy; presentation layers are
/// responsible for mapping [code] to a localized message shown to the user.
class AuthFailure extends Equatable implements Exception {
  const AuthFailure(this.code, {this.message});

  final AuthFailureCode code;
  final String? message;

  @override
  List<Object?> get props => [code, message];

  @override
  String toString() => 'AuthFailure(code: $code, message: $message)';
}

enum AuthFailureCode {
  invalidCredentials,
  emailAlreadyInUse,
  weakPassword,
  invalidEmail,
  tooManyRequests,
  network,
  disabled,
  pending,
  unauthorized,
  unknown,
}

extension AuthFailureCodeX on AuthFailureCode {
  String get value => name;

  static AuthFailureCode? tryFromValue(String? value) {
    for (final code in AuthFailureCode.values) {
      if (code.value == value) return code;
    }
    return null;
  }
}

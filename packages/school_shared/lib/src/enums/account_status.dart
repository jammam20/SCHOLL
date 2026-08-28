enum AccountStatus {
  pending,
  active,
  rejected,
  disabled;

  String get value => name;

  static AccountStatus fromValue(Object? value) {
    if (value is String) {
      for (final status in AccountStatus.values) {
        if (status.value == value) return status;
      }
    }

    return AccountStatus.pending;
  }
}
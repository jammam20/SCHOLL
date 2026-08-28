enum UserRole {
  admin,
  driver,
  parent;

  String get value => name;

  static UserRole? tryParse(Object? value) {
    if (value is! String) return null;

    for (final role in UserRole.values) {
      if (role.value == value) return role;
    }

    return null;
  }
}
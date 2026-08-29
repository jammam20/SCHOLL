enum UserRole {
  admin,
  driver,
  parent,
  // Read-only operational visibility (buses/routes/students/boarding/
  // arrivals/attendance/alerts) for school staff who aren't drivers or
  // parents and shouldn't get admin's management/write capabilities. Gated
  // separately from `admin` everywhere a rule or UI branches on role —
  // never treated as a subset of admin.
  staff;

  String get value => name;

  static UserRole? tryParse(Object? value) {
    if (value is! String) return null;

    for (final role in UserRole.values) {
      if (role.value == value) return role;
    }

    return null;
  }
}
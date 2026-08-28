enum MembershipStatus { pending, approved, rejected, suspended, inactive }

extension MembershipStatusX on MembershipStatus {
  String get value => name;

  static MembershipStatus? tryFromValue(String? value) {
    for (final status in MembershipStatus.values) {
      if (status.value == value) return status;
    }
    return null;
  }
}

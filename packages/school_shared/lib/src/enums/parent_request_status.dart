/// Where a parent's message/request to the school stands. Deliberately
/// tiny: a parent only ever creates an `open` request (firestore.rules
/// enforces that), and only a school admin can move it to `read` or
/// `closed` — there is no parent-side "reopen" or "escalate" path, because
/// the whole point of this collection is that the school stays the single
/// router between a parent and a driver.
enum ParentRequestStatus { open, read, closed }

extension ParentRequestStatusX on ParentRequestStatus {
  String get value => name;

  static ParentRequestStatus? tryParse(Object? value) {
    if (value is! String) return null;
    for (final status in ParentRequestStatus.values) {
      if (status.value == value) return status;
    }
    return null;
  }
}

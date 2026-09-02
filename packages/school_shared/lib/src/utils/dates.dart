/// Formats [date] as 'yyyy-MM-dd' — the shape stored in `Student.absentOn`.
/// Kept dependency-free (no `intl`) since it's just used for date-only
/// equality checks, not display.
String isoDateOnly(DateTime date) {
  String pad2(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${pad2(date.month)}-${pad2(date.day)}';
}

/// Today's date, formatted the same way `Student.absentOn` is stored.
String todayIsoDate() => isoDateOnly(DateTime.now());

/// Converts a local wall-clock time to "minutes since UTC midnight" — the
/// convention `SchoolRoute.outboundScheduledMinutes`/`returnScheduledMinutes`
/// are stored in, so that firestore.rules' absence-cutoff/trip-start-window
/// checks (which only have `request.time.date()`, always UTC midnight) land
/// on the instant the admin actually picked. Only the hour/minute-of-day
/// matters here — which calendar day the intermediate conversion lands on
/// is irrelevant and discarded.
int localTimeToUtcMinutes(int hour, int minute) {
  final utc = DateTime(2000, 1, 1, hour, minute).toUtc();
  return utc.hour * 60 + utc.minute;
}

/// The inverse of [localTimeToUtcMinutes] — recovers the admin's own local
/// hour/minute from a stored UTC-minutes value, for display/editing.
(int hour, int minute) utcMinutesToLocalTime(int utcMinutes) {
  final local = DateTime.utc(
    2000,
    1,
    1,
    utcMinutes ~/ 60,
    utcMinutes % 60,
  ).toLocal();
  return (local.hour, local.minute);
}

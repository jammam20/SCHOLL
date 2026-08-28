/// Formats [date] as 'yyyy-MM-dd' — the shape stored in `Student.absentOn`.
/// Kept dependency-free (no `intl`) since it's just used for date-only
/// equality checks, not display.
String isoDateOnly(DateTime date) {
  String pad2(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${pad2(date.month)}-${pad2(date.day)}';
}

/// Today's date, formatted the same way `Student.absentOn` is stored.
String todayIsoDate() => isoDateOnly(DateTime.now());

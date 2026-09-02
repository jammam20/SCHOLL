import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_shared/school_shared.dart';

/// Small composition helpers shared by the parent app's message, notification,
/// child-settings, notification-preference, profile and legal screens.
///
/// [InfoNotice], [AppListCard], [SettingsTile], [InitialAvatar] and
/// [toneColor] used to be defined here; they're now
/// `packages/school_shared/lib/src/design/components/detail_list.dart` (and
/// `status_badge.dart` for `toneColor`) so the admin app's student/parent/
/// driver detail views can reuse the exact same shapes instead of a second
/// hand-rolled copy — every call site in this app already imports
/// `school_shared.dart` directly, so nothing here needed to change beyond
/// removing the now-duplicate definitions.

/// A page transition that fades and lifts slightly instead of the platform's
/// default slide, at the design system's own [AppDurations.pageTransition] —
/// used for opening a conversation from the thread list, where the default
/// push made a chat feel like a separate app rather than the same list
/// expanding. Honors the platform "reduce motion" setting by falling back to
/// a plain fade.
Route<T> appFadeThroughRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: AppDurations.pageTransition,
    reverseTransitionDuration: AppDurations.stateSwitch,
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeIn,
      );
      final fade = FadeTransition(opacity: curved, child: child);
      if (MediaQuery.of(context).disableAnimations) return fade;
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(curved),
        child: fade,
      );
    },
  );
}

/// Whether [date] falls on the same calendar day as [other].
bool isSameDay(DateTime date, DateTime other) =>
    date.year == other.year && date.month == other.month && date.day == other.day;

/// "Today" / "Yesterday" / "Tomorrow" where that reads better than a date,
/// otherwise a short date.
///
/// The [DateFormat] calls are deliberately locale-less, matching every other
/// date in this app: no `initializeDateFormatting` call exists anywhere in
/// this project, so asking `intl` for Arabic date symbols would throw at
/// runtime. Only the relative words are translated.
String friendlyDay(BuildContext context, DateTime date) {
  final now = DateTime.now();
  if (isSameDay(date, now)) {
    return const S('Today', 'النهاردة').of(context);
  }
  if (isSameDay(date, now.subtract(const Duration(days: 1)))) {
    return const S('Yesterday', 'إمبارح').of(context);
  }
  if (isSameDay(date, now.add(const Duration(days: 1)))) {
    return const S('Tomorrow', 'بكرة').of(context);
  }
  if (date.year == now.year) return DateFormat('EEE, d MMM').format(date);
  return DateFormat('d MMM yyyy').format(date);
}

/// A day plus a clock time — "Today · 3:40 PM", "12 Mar · 8:05 AM".
String friendlyDateTime(BuildContext context, DateTime timestamp) =>
    '${friendlyDay(context, timestamp)} · ${DateFormat.jm().format(timestamp)}';

/// A compact "when did this happen" label for a list row: a clock time for
/// today, a relative word for yesterday/tomorrow, a short date beyond that.
String compactTimestamp(BuildContext context, DateTime timestamp) {
  final now = DateTime.now();
  if (isSameDay(timestamp, now)) return DateFormat.jm().format(timestamp);
  return friendlyDay(context, timestamp);
}

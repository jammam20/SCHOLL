import 'package:flutter/material.dart';
import 'package:school_shared/school_shared.dart';

/// How each real notification event type is presented in the inbox.
///
/// Kept out of the page widget so the mapping can be tested directly against
/// the server contract: these strings are not a design choice, they are the
/// exact `type` values `writeNotificationRecords` stamps on documents at
/// `users/{uid}/notifications/{id}` (see `functions/src/index.ts`). If a new
/// event type is added there, the test in
/// `test/notification_type_visuals_test.dart` fails until it is given a
/// presentation here rather than silently falling through to the neutral
/// default.

/// Every `type` the Cloud Functions actually write, enumerated from the
/// `writeNotificationRecords(...)` call sites in `functions/src/index.ts`.
///
/// `route_deviation` is written for school admins rather than parents, and
/// is listed (and handled) anyway: the collection is per-user, this app can
/// be signed into by a user who is also an admin elsewhere, and a document
/// that exists should never render as an unlabelled blank.
const kServerNotificationTypes = <String>{
  'trip',
  'emergency',
  'student_boarded',
  'student_dropped_off',
  'bus_changed',
  'route_deviation',
  'school_message',
  'parent_message',
};

/// An unrecognized type still renders, neutrally, rather than being hidden: a
/// notification a parent was pushed should never silently vanish from the
/// inbox just because this app is older than the server that wrote it.
IconData notificationTypeIcon(String type) => switch (type) {
  'trip' => Icons.directions_bus_rounded,
  'emergency' => Icons.warning_amber_rounded,
  'student_boarded' => Icons.how_to_reg_rounded,
  'student_dropped_off' => Icons.waving_hand_outlined,
  'bus_changed' => Icons.swap_horiz_rounded,
  'route_deviation' => Icons.alt_route_rounded,
  'school_message' => Icons.campaign_outlined,
  'parent_message' => Icons.forum_outlined,
  _ => Icons.notifications_none_rounded,
};

/// The severity each type carries. An emergency is the only thing that gets
/// [StatusTone.emergency]; boarding/drop-off are reassuring rather than
/// alarming; a bus change or a route deviation is a caution, not a crisis.
StatusTone notificationTypeTone(String type) => switch (type) {
  'trip' => StatusTone.info,
  'emergency' => StatusTone.emergency,
  'student_boarded' => StatusTone.success,
  'student_dropped_off' => StatusTone.success,
  'bus_changed' => StatusTone.warning,
  'route_deviation' => StatusTone.warning,
  'school_message' => StatusTone.info,
  'parent_message' => StatusTone.info,
  _ => StatusTone.neutral,
};

/// A short human name for the event type, so the badge says what kind of
/// thing this was without the parent having to parse the body text.
S notificationTypeLabel(String type) => switch (type) {
  'trip' => const S('Trip', 'الرحلة'),
  'emergency' => const S('Emergency', 'طوارئ'),
  'student_boarded' => const S('Boarded', 'ركب'),
  'student_dropped_off' => const S('Dropped off', 'نزل'),
  'bus_changed' => const S('Bus changed', 'الأتوبيس اتغير'),
  'route_deviation' => const S('Route deviation', 'خروج عن الخط'),
  'school_message' => const S('School message', 'رسالة من المدرسة'),
  'parent_message' => const S('School reply', 'رد المدرسة'),
  _ => const S('Update', 'تحديث'),
};

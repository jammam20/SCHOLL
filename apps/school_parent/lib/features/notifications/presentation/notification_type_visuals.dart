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
  // Trip lifecycle. 'trip' and 'bus_changed' are the pre-4-language names
  // still present on older records; the server now writes the specific
  // types below so each event can be re-rendered from its own template.
  'trip',
  'trip_starting',
  'trip_paused',
  'trip_completed',
  'trip_cancelled',
  'emergency',
  'student_boarded',
  'student_not_at_stop',
  'student_dropped_off',
  'bus_changed',
  'trip_bus_changed',
  'trip_driver_changed',
  'trip_bus_and_driver_changed',
  'bus_arriving',
  'bus_minutes_away',
  'bus_arrived_school',
  'route_deviation',
  'school_message',
  'parent_message',
  'school_message_reply',
  // Community moderation — the server has always written these three, but
  // they were missing here, so they fell through to a generic "Update".
  'community_post_hidden',
  'community_admin_replied',
  'community_report_resolved',
};

/// An unrecognized type still renders, neutrally, rather than being hidden: a
/// notification a parent was pushed should never silently vanish from the
/// inbox just because this app is older than the server that wrote it.
IconData notificationTypeIcon(String type) => switch (type) {
  'trip' ||
  'trip_starting' ||
  'trip_paused' ||
  'trip_completed' => Icons.directions_bus_rounded,
  'trip_cancelled' => Icons.cancel_outlined,
  'emergency' => Icons.warning_amber_rounded,
  'student_boarded' => Icons.how_to_reg_rounded,
  'student_not_at_stop' => Icons.person_search_rounded,
  'student_dropped_off' => Icons.waving_hand_outlined,
  'bus_changed' ||
  'trip_bus_changed' ||
  'trip_driver_changed' ||
  'trip_bus_and_driver_changed' => Icons.swap_horiz_rounded,
  'bus_arriving' || 'bus_minutes_away' => Icons.near_me_outlined,
  'bus_arrived_school' => Icons.school_outlined,
  'route_deviation' => Icons.alt_route_rounded,
  'school_message' => Icons.campaign_outlined,
  'parent_message' || 'school_message_reply' => Icons.forum_outlined,
  'community_post_hidden' => Icons.visibility_off_outlined,
  'community_admin_replied' => Icons.mark_chat_read_outlined,
  'community_report_resolved' => Icons.flag_outlined,
  _ => Icons.notifications_none_rounded,
};

/// The severity each type carries. An emergency is the only thing that gets
/// [StatusTone.emergency]; boarding/drop-off are reassuring rather than
/// alarming; a bus change or a route deviation is a caution, not a crisis.
StatusTone notificationTypeTone(String type) => switch (type) {
  'trip' ||
  'trip_starting' ||
  'trip_paused' ||
  'bus_arriving' ||
  'bus_minutes_away' => StatusTone.info,
  'emergency' => StatusTone.emergency,
  'student_not_at_stop' => StatusTone.error,
  'student_boarded' ||
  'student_dropped_off' ||
  'trip_completed' ||
  'bus_arrived_school' => StatusTone.success,
  'trip_cancelled' ||
  'bus_changed' ||
  'trip_bus_changed' ||
  'trip_driver_changed' ||
  'trip_bus_and_driver_changed' ||
  'route_deviation' ||
  'community_post_hidden' => StatusTone.warning,
  'school_message' ||
  'parent_message' ||
  'school_message_reply' ||
  'community_admin_replied' ||
  'community_report_resolved' => StatusTone.info,
  _ => StatusTone.neutral,
};

/// A short human name for the event type, so the badge says what kind of
/// thing this was without the parent having to parse the body text.
S notificationTypeLabel(String type) => switch (type) {
  'trip' => const S('Trip', 'الرحلة', fr: 'Trajet', es: 'Viaje'),
  'trip_starting' => const S(
    'Trip started',
    'الرحلة بدأت',
    fr: 'Trajet démarré',
    es: 'Viaje iniciado',
  ),
  'trip_paused' => const S(
    'Trip paused',
    'الرحلة متوقفة',
    fr: 'Trajet en pause',
    es: 'Viaje en pausa',
  ),
  'trip_completed' => const S(
    'Trip finished',
    'الرحلة خلصت',
    fr: 'Trajet terminé',
    es: 'Viaje finalizado',
  ),
  'trip_cancelled' => const S(
    'Trip cancelled',
    'الرحلة اتلغت',
    fr: 'Trajet annulé',
    es: 'Viaje cancelado',
  ),
  'emergency' => const S(
    'Emergency',
    'طوارئ',
    fr: 'Urgence',
    es: 'Emergencia',
  ),
  'student_not_at_stop' => const S(
    'Not at stop',
    'مكانش في المحطة',
    fr: "Absent à l'arrêt",
    es: 'No estaba',
  ),
  'student_boarded' => const S(
    'Boarded',
    'ركب',
    fr: 'Monté',
    es: 'Subió',
  ),
  'student_dropped_off' => const S(
    'Dropped off',
    'نزل',
    fr: 'Déposé',
    es: 'Bajó',
  ),
  'bus_changed' ||
  'trip_bus_changed' ||
  'trip_driver_changed' ||
  'trip_bus_and_driver_changed' => const S(
    'Bus changed',
    'الأتوبيس اتغير',
    fr: 'Bus modifié',
    es: 'Autobús cambiado',
  ),
  'bus_arriving' => const S(
    'Arriving',
    'بيوصل',
    fr: 'En approche',
    es: 'Llegando',
  ),
  'bus_minutes_away' => const S(
    'On the way',
    'في الطريق',
    fr: 'En route',
    es: 'En camino',
  ),
  'bus_arrived_school' => const S(
    'Arrived at school',
    'وصل المدرسة',
    fr: "Arrivé à l'école",
    es: 'Llegó a la escuela',
  ),
  'route_deviation' => const S(
    'Route deviation',
    'خروج عن الخط',
    fr: "Écart d'itinéraire",
    es: 'Desvío de ruta',
  ),
  'school_message' => const S(
    'School message',
    'رسالة من المدرسة',
    fr: "Message de l'école",
    es: 'Mensaje de la escuela',
  ),
  'parent_message' || 'school_message_reply' => const S(
    'School reply',
    'رد المدرسة',
    fr: "Réponse de l'école",
    es: 'Respuesta de la escuela',
  ),
  'community_post_hidden' => const S(
    'Post hidden',
    'المشاركة اتخفيت',
    fr: 'Publication masquée',
    es: 'Publicación oculta',
  ),
  'community_admin_replied' => const S(
    'Community reply',
    'رد على مشاركتك',
    fr: 'Réponse à votre publication',
    es: 'Respuesta a tu publicación',
  ),
  'community_report_resolved' => const S(
    'Report reviewed',
    'البلاغ اتراجع',
    fr: 'Signalement examiné',
    es: 'Reporte revisado',
  ),
  _ => const S('Update', 'تحديث', fr: 'Mise à jour', es: 'Actualización'),
};

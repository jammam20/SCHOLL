import 'package:flutter/widgets.dart';
import 'package:school_shared/school_shared.dart';

/// Renders a stored notification in the language the app is in *now*.
///
/// The server writes each inbox entry as a `type` plus the values it would
/// have interpolated (`params`), not as a finished sentence, so the same
/// record reads correctly whatever language the parent later switches to.
/// Previously the English text was frozen into Firestore at send time and
/// the inbox rendered it verbatim — which is why the notification history
/// stayed English even with the app in Arabic.
///
/// Mirrors the table in functions/src/notification_messages.ts — the two
/// must agree on type names and placeholder names. The server still writes
/// a rendered `title`/`body` alongside, and [notificationBodyText] falls
/// back to it for records written before this existed.
String notificationBodyText(AppNotification notification, BuildContext context) {
  final phrase = _bodies[notification.type];
  if (phrase == null) return notification.body;

  final emoji = _emoji[notification.type];
  final text = _fill(phrase.of(context), notification.params, context);
  return emoji == null ? text : '$emoji $text';
}

String notificationTitleText(
  AppNotification notification,
  BuildContext context,
) {
  final phrase = _titles[notification.type] ?? _appName;
  // A school broadcast carries the admin's own words, including their own
  // title — never overwrite that with a generic one.
  if (notification.type == 'school_message') return notification.title;
  return phrase.of(context);
}

/// Substitutes `{placeholder}` values, falling back per language for the
/// ones the source document didn't carry.
String _fill(
  String template,
  Map<String, Object?> params,
  BuildContext context,
) {
  String valueFor(String key) {
    final raw = params[key];
    final value = raw == null ? '' : raw.toString();
    if (value.isNotEmpty) return value;
    return switch (key) {
      'routeName' => _fallbackBus.of(context),
      'studentName' => _fallbackChild.of(context),
      'busName' => _fallbackOtherBus.of(context),
      'subject' => _fallbackSubject.of(context),
      _ => '',
    };
  }

  return template.replaceAllMapped(
    RegExp(r'\{(\w+)\}'),
    (match) => valueFor(match.group(1)!),
  );
}

const _appName = S(
  'School Bus',
  'أتوبيس المدرسة',
  fr: 'Bus scolaire',
  es: 'Autobús escolar',
);

const _fallbackBus = S(
  'Your bus',
  'أتوبيسك',
  fr: 'Votre bus',
  es: 'Tu autobús',
);
const _fallbackChild = S(
  'Your child',
  'طفلك',
  fr: 'Votre enfant',
  es: 'Tu hijo/a',
);
const _fallbackOtherBus = S(
  'a different bus',
  'أتوبيس تاني',
  fr: 'un autre bus',
  es: 'otro autobús',
);
const _fallbackSubject = S(
  'your message',
  'رسالتك',
  fr: 'votre message',
  es: 'tu mensaje',
);

const _titles = <String, S>{
  'bus_arriving': S(
    'Bus arriving',
    'الأتوبيس بيوصل',
    fr: 'Bus en approche',
    es: 'El autobús está llegando',
  ),
  'bus_minutes_away': S(
    'Bus on the way',
    'الأتوبيس في الطريق',
    fr: 'Bus en route',
    es: 'Autobús en camino',
  ),
  'bus_arrived_school': S(
    'Bus arrived',
    'الأتوبيس وصل',
    fr: 'Bus arrivé',
    es: 'El autobús llegó',
  ),
  'route_deviation': S(
    'Route deviation',
    'خروج عن المسار',
    fr: "Écart d'itinéraire",
    es: 'Desvío de ruta',
  ),
};

const _emoji = <String, String>{
  'emergency': '⚠️',
  'trip_starting': '🚌',
  'trip_paused': '🚌',
  'trip_completed': '🚌',
  'trip_cancelled': '🚌',
  'student_boarded': '✅',
  'student_dropped_off': '🏫',
  'trip_bus_changed': '🚍',
  'trip_driver_changed': '🚍',
  'trip_bus_and_driver_changed': '🚍',
  'bus_arriving': '🚌',
  'bus_minutes_away': '🚌',
  'bus_arrived_school': '🚌',
  'route_deviation': '🛑',
  'parent_message': '💬',
  'school_message_reply': '💬',
  'community_admin_replied': '🏫',
};

const _bodies = <String, S>{
  'emergency': S(
    '{routeName} reported an emergency.',
    '{routeName} أبلغت عن حالة طوارئ.',
    fr: '{routeName} a signalé une urgence.',
    es: '{routeName} informó una emergencia.',
  ),
  'trip_starting': S(
    '{routeName} is starting its route.',
    '{routeName} بدأت رحلتها.',
    fr: '{routeName} commence son itinéraire.',
    es: '{routeName} está comenzando su ruta.',
  ),
  'trip_paused': S(
    '{routeName} has paused.',
    '{routeName} توقفت مؤقتاً.',
    fr: '{routeName} est en pause.',
    es: '{routeName} se ha detenido.',
  ),
  'trip_completed': S(
    '{routeName} has completed its trip.',
    '{routeName} خلصت رحلتها.',
    fr: '{routeName} a terminé son trajet.',
    es: '{routeName} completó su viaje.',
  ),
  'trip_cancelled': S(
    'The {routeName} trip was cancelled.',
    'رحلة {routeName} اتلغت.',
    fr: 'Le trajet {routeName} a été annulé.',
    es: 'El viaje de {routeName} fue cancelado.',
  ),
  'student_boarded': S(
    '{studentName} boarded the {routeName} bus.',
    '{studentName} ركب أتوبيس {routeName}.',
    fr: '{studentName} est monté(e) dans le bus {routeName}.',
    es: '{studentName} subió al autobús {routeName}.',
  ),
  'student_dropped_off': S(
    '{studentName} was dropped off from the {routeName} bus.',
    '{studentName} نزل من أتوبيس {routeName}.',
    fr: '{studentName} est descendu(e) du bus {routeName}.',
    es: '{studentName} bajó del autobús {routeName}.',
  ),
  'trip_bus_changed': S(
    '{routeName}: bus changed to {busName}.',
    '{routeName}: الأتوبيس اتغير لـ {busName}.',
    fr: '{routeName} : bus remplacé par {busName}.',
    es: '{routeName}: el autobús cambió a {busName}.',
  ),
  'trip_driver_changed': S(
    '{routeName}: driver changed.',
    '{routeName}: السواق اتغير.',
    fr: '{routeName} : chauffeur changé.',
    es: '{routeName}: el conductor cambió.',
  ),
  'trip_bus_and_driver_changed': S(
    '{routeName}: bus changed to {busName}, driver changed.',
    '{routeName}: الأتوبيس اتغير لـ {busName}، والسواق اتغير.',
    fr: '{routeName} : bus remplacé par {busName}, chauffeur changé.',
    es: '{routeName}: el autobús cambió a {busName} y el conductor cambió.',
  ),
  'bus_arriving': S(
    "The {routeName} bus is arriving at {studentName}'s pickup point.",
    'أتوبيس {routeName} بيوصل نقطة استلام {studentName}.',
    fr: 'Le bus {routeName} arrive au point de ramassage de {studentName}.',
    es: 'El autobús {routeName} está llegando al punto de recogida de {studentName}.',
  ),
  'bus_minutes_away': S(
    'The {routeName} bus is about {minutes} min from {studentName}.',
    'أتوبيس {routeName} على بعد حوالي {minutes} دقيقة من {studentName}.',
    fr: 'Le bus {routeName} est à environ {minutes} min de {studentName}.',
    es: 'El autobús {routeName} está a unos {minutes} min de {studentName}.',
  ),
  'bus_arrived_school': S(
    'The {routeName} bus has arrived at school.',
    'أتوبيس {routeName} وصل المدرسة.',
    fr: "Le bus {routeName} est arrivé à l'école.",
    es: 'El autobús {routeName} llegó a la escuela.',
  ),
  'route_deviation': S(
    '{routeName} has deviated from its expected route.',
    '{routeName} خرجت عن مسارها المتوقع.',
    fr: "{routeName} s'est écarté de son itinéraire prévu.",
    es: '{routeName} se ha desviado de su ruta prevista.',
  ),
  'parent_message': S(
    'New message about {subject}: {preview}',
    'رسالة جديدة بخصوص {subject}: {preview}',
    fr: 'Nouveau message à propos de {subject} : {preview}',
    es: 'Nuevo mensaje sobre {subject}: {preview}',
  ),
  'school_message_reply': S(
    'Your school replied: {preview}',
    'مدرستك ردت: {preview}',
    fr: 'Votre école a répondu : {preview}',
    es: 'Tu escuela respondió: {preview}',
  ),
  'community_post_hidden': S(
    "Your community post was hidden by your school's admin.",
    'مشاركتك في المجتمع اتخفيت من إدارة المدرسة.',
    fr: "Votre publication a été masquée par l'administration de l'école.",
    es: 'Tu publicación fue ocultada por la administración de la escuela.',
  ),
  'community_admin_replied': S(
    'Your school replied to your community post: {preview}',
    'مدرستك ردت على مشاركتك في المجتمع: {preview}',
    fr: 'Votre école a répondu à votre publication : {preview}',
    es: 'Tu escuela respondió a tu publicación: {preview}',
  ),
  'community_report_resolved': S(
    'Your school reviewed the post you reported.',
    'مدرستك راجعت المشاركة اللي بلغت عنها.',
    fr: "Votre école a examiné la publication que vous avez signalée.",
    es: 'Tu escuela revisó la publicación que reportaste.',
  ),
};

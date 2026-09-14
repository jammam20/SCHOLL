/// Every user-facing string a push notification can contain, in each
/// language the apps ship.
///
/// Notifications used to be built as hardcoded English template literals
/// inline in index.ts, and the backend had no idea what language the
/// recipient reads — so every push arrived in English no matter what the
/// app was set to. The apps now mirror the chosen language into
/// `users/{uid}.notificationPrefs.language`, and this module turns an event
/// plus its values into text in that language.
///
/// Kept as one table rather than scattered inline strings so that adding a
/// language is a column, not a hunt through fourteen call sites — and so
/// the set of things we say to people is reviewable in one place.

/// Language codes the apps ship. Mirrors `AppLanguage` in
/// packages/school_shared/lib/src/design/app_settings.dart — keep in sync.
export const SUPPORTED_LANGUAGES = ["en", "ar", "fr", "es"] as const;
export type Language = (typeof SUPPORTED_LANGUAGES)[number];

export const DEFAULT_LANGUAGE: Language = "en";

/// Normalises whatever is stored on the user document. Anything unknown,
/// missing or malformed falls back to English rather than throwing — a bad
/// preference must never stop a safety notification going out.
export function languageOf(
  data: FirebaseFirestore.DocumentData | undefined,
): Language {
  const raw = (data?.notificationPrefs ?? {}) as Record<string, unknown>;
  const code = typeof raw.language === "string" ? raw.language : "";
  return (SUPPORTED_LANGUAGES as readonly string[]).includes(code)
    ? (code as Language)
    : DEFAULT_LANGUAGE;
}

type Phrase = Record<Language, string>;

/// Values interpolated into a message. Names are deliberately generic so
/// the same placeholder set works across languages whose word order differs.
export interface MessageParams {
  routeName?: string;
  studentName?: string;
  busName?: string;
  subject?: string;
  preview?: string;
  minutes?: number;
}

/// Placeholder names used inside the templates below.
const PLACEHOLDER = /\{(\w+)\}/g;

function fill(template: string, params: MessageParams): string {
  return template.replace(PLACEHOLDER, (_match, key: string) => {
    const value = (params as Record<string, unknown>)[key];
    return value === undefined || value === null ? "" : String(value);
  });
}

/// Fallback names for values the trip/student documents didn't carry.
/// These used to be English literals baked into the interpolations
/// (`routeName ?? "Your bus"`), which leaked English into an otherwise
/// translated sentence.
const FALLBACKS: Record<"bus" | "child" | "otherBus" | "subject", Phrase> = {
  subject: {
    en: "your message",
    ar: "رسالتك",
    fr: "votre message",
    es: "tu mensaje",
  },
  bus: {
    en: "Your bus",
    ar: "أتوبيسك",
    fr: "Votre bus",
    es: "Tu autobús",
  },
  child: {
    en: "Your child",
    ar: "طفلك",
    fr: "Votre enfant",
    es: "Tu hijo/a",
  },
  otherBus: {
    en: "a different bus",
    ar: "أتوبيس تاني",
    fr: "un autre bus",
    es: "otro autobús",
  },
};

export function fallbackBusName(language: Language): string {
  return FALLBACKS.bus[language];
}

export function fallbackChildName(language: Language): string {
  return FALLBACKS.child[language];
}

export function fallbackOtherBusName(language: Language): string {
  return FALLBACKS.otherBus[language];
}

/// The title shown above every notification body.
const TITLES: Record<string, Phrase> = {
  appName: {
    en: "School Bus",
    ar: "أتوبيس المدرسة",
    fr: "Bus scolaire",
    es: "Autobús escolar",
  },
  busArriving: {
    en: "Bus arriving",
    ar: "الأتوبيس بيوصل",
    fr: "Bus en approche",
    es: "El autobús está llegando",
  },
  busOnTheWay: {
    en: "Bus on the way",
    ar: "الأتوبيس في الطريق",
    fr: "Bus en route",
    es: "Autobús en camino",
  },
  busArrived: {
    en: "Bus arrived",
    ar: "الأتوبيس وصل",
    fr: "Bus arrivé",
    es: "El autobús llegó",
  },
  routeDeviation: {
    en: "Route deviation",
    ar: "خروج عن المسار",
    fr: "Écart d'itinéraire",
    es: "Desvío de ruta",
  },
  notAtStop: {
    en: "Not at the stop",
    ar: "مكانش في المحطة",
    fr: "Absent à l'arrêt",
    es: "No estaba en la parada",
  },
};

/// Every notification body, keyed by the `type` also written to the in-app
/// inbox so the Flutter side can re-render the same event in whatever
/// language is active at read time.
const BODIES: Record<string, Phrase> = {
  emergency: {
    en: "{routeName} reported an emergency.",
    ar: "{routeName} أبلغت عن حالة طوارئ.",
    fr: "{routeName} a signalé une urgence.",
    es: "{routeName} informó una emergencia.",
  },
  trip_starting: {
    en: "{routeName} is starting its route.",
    ar: "{routeName} بدأت رحلتها.",
    fr: "{routeName} commence son itinéraire.",
    es: "{routeName} está comenzando su ruta.",
  },
  trip_paused: {
    en: "{routeName} has paused.",
    ar: "{routeName} توقفت مؤقتاً.",
    fr: "{routeName} est en pause.",
    es: "{routeName} se ha detenido.",
  },
  trip_completed: {
    en: "{routeName} has completed its trip.",
    ar: "{routeName} خلصت رحلتها.",
    fr: "{routeName} a terminé son trajet.",
    es: "{routeName} completó su viaje.",
  },
  // Previously "{routeName} trip was cancelled." — ungrammatical because
  // it reused a fragment table shared with the sentences above.
  trip_cancelled: {
    en: "The {routeName} trip was cancelled.",
    ar: "رحلة {routeName} اتلغت.",
    fr: "Le trajet {routeName} a été annulé.",
    es: "El viaje de {routeName} fue cancelado.",
  },
  student_not_at_stop: {
    en:
      "The {routeName} bus reached {studentName}'s stop and they were not " +
      "there. If they are not riding today, mark them absent in the app.",
    ar:
      "أتوبيس {routeName} وصل محطة {studentName} وملقهوش. لو مش هيركب " +
      "النهاردة، سجّله غايب من التطبيق.",
    fr:
      "Le bus {routeName} est arrivé à l'arrêt de {studentName} et " +
      "l'enfant n'y était pas. S'il ne prend pas le bus aujourd'hui, " +
      "marquez-le absent dans l'application.",
    es:
      "El autobús de {routeName} llegó a la parada de {studentName} y no " +
      "estaba allí. Si hoy no viaja, márquelo como ausente en la " +
      "aplicación.",
  },
  student_boarded: {
    en: "{studentName} boarded the {routeName} bus.",
    ar: "{studentName} ركب أتوبيس {routeName}.",
    fr: "{studentName} est monté(e) dans le bus {routeName}.",
    es: "{studentName} subió al autobús {routeName}.",
  },
  student_dropped_off: {
    en: "{studentName} was dropped off from the {routeName} bus.",
    ar: "{studentName} نزل من أتوبيس {routeName}.",
    fr: "{studentName} est descendu(e) du bus {routeName}.",
    es: "{studentName} bajó del autobús {routeName}.",
  },
  trip_bus_changed: {
    en: "{routeName}: bus changed to {busName}.",
    ar: "{routeName}: الأتوبيس اتغير لـ {busName}.",
    fr: "{routeName} : bus remplacé par {busName}.",
    es: "{routeName}: el autobús cambió a {busName}.",
  },
  trip_driver_changed: {
    en: "{routeName}: driver changed.",
    ar: "{routeName}: السواق اتغير.",
    fr: "{routeName} : chauffeur changé.",
    es: "{routeName}: el conductor cambió.",
  },
  trip_bus_and_driver_changed: {
    en: "{routeName}: bus changed to {busName}, driver changed.",
    ar: "{routeName}: الأتوبيس اتغير لـ {busName}، والسواق اتغير.",
    fr: "{routeName} : bus remplacé par {busName}, chauffeur changé.",
    es: "{routeName}: el autobús cambió a {busName} y el conductor cambió.",
  },
  bus_arriving: {
    en: "The {routeName} bus is arriving at {studentName}'s pickup point.",
    ar: "أتوبيس {routeName} بيوصل نقطة استلام {studentName}.",
    fr: "Le bus {routeName} arrive au point de ramassage de {studentName}.",
    es: "El autobús {routeName} está llegando al punto de recogida de {studentName}.",
  },
  bus_minutes_away: {
    en: "The {routeName} bus is about {minutes} min from {studentName}.",
    ar: "أتوبيس {routeName} على بعد حوالي {minutes} دقيقة من {studentName}.",
    fr: "Le bus {routeName} est à environ {minutes} min de {studentName}.",
    es: "El autobús {routeName} está a unos {minutes} min de {studentName}.",
  },
  bus_arrived_school: {
    en: "The {routeName} bus has arrived at school.",
    ar: "أتوبيس {routeName} وصل المدرسة.",
    fr: "Le bus {routeName} est arrivé à l'école.",
    es: "El autobús {routeName} llegó a la escuela.",
  },
  route_deviation: {
    en: "{routeName} has deviated from its expected route.",
    ar: "{routeName} خرجت عن مسارها المتوقع.",
    fr: "{routeName} s'est écarté de son itinéraire prévu.",
    es: "{routeName} se ha desviado de su ruta prevista.",
  },
  parent_message: {
    en: "New message about {subject}: {preview}",
    ar: "رسالة جديدة بخصوص {subject}: {preview}",
    fr: "Nouveau message à propos de {subject} : {preview}",
    es: "Nuevo mensaje sobre {subject}: {preview}",
  },
  school_message_reply: {
    en: "Your school replied: {preview}",
    ar: "مدرستك ردت: {preview}",
    fr: "Votre école a répondu : {preview}",
    es: "Tu escuela respondió: {preview}",
  },
  community_post_hidden: {
    en: "Your community post was hidden by your school's admin.",
    ar: "مشاركتك في المجتمع اتخفيت من إدارة المدرسة.",
    fr: "Votre publication a été masquée par l'administration de l'école.",
    es: "Tu publicación fue ocultada por la administración de la escuela.",
  },
  community_admin_replied: {
    en: "Your school replied to your community post: {preview}",
    ar: "مدرستك ردت على مشاركتك في المجتمع: {preview}",
    fr: "Votre école a répondu à votre publication : {preview}",
    es: "Tu escuela respondió a tu publicación: {preview}",
  },
  community_report_resolved: {
    en: "Your school reviewed the post you reported.",
    ar: "مدرستك راجعت المشاركة اللي بلغت عنها.",
    fr: "Votre école a examiné la publication que vous avez signalée.",
    es: "Tu escuela revisó la publicación que reportaste.",
  },
};

/// Emoji stay outside the translated strings — they're identical in every
/// language, and keeping them out means a translator never has to preserve
/// one (or accidentally drop one).
const EMOJI: Record<string, string> = {
  emergency: "⚠️",
  trip_starting: "🚌",
  trip_paused: "🚌",
  trip_completed: "🚌",
  trip_cancelled: "🚌",
  student_not_at_stop: "⚠️",
  student_boarded: "✅",
  student_dropped_off: "🏫",
  trip_bus_changed: "🚍",
  trip_driver_changed: "🚍",
  trip_bus_and_driver_changed: "🚍",
  bus_arriving: "🚌",
  bus_minutes_away: "🚌",
  bus_arrived_school: "🚌",
  route_deviation: "🛑",
  parent_message: "💬",
  school_message_reply: "💬",
  community_admin_replied: "🏫",
};

/// Which title each body uses.
const TITLE_FOR_TYPE: Record<string, keyof typeof TITLES> = {
  bus_arriving: "busArriving",
  bus_minutes_away: "busOnTheWay",
  bus_arrived_school: "busArrived",
  route_deviation: "routeDeviation",
  student_not_at_stop: "notAtStop",
};

export function notificationTitle(type: string, language: Language): string {
  const key = TITLE_FOR_TYPE[type] ?? "appName";
  return TITLES[key][language];
}

export function notificationBody(
  type: string,
  language: Language,
  params: MessageParams = {},
): string {
  const phrase = BODIES[type];
  if (!phrase) return "";
  const emoji = EMOJI[type];
  // Fallbacks are resolved here, per language, rather than at the call
  // site: the caller reads the trip/student document long before it knows
  // who it's sending to, so a fallback chosen there would be one fixed
  // language for everyone (which is exactly how "Your bus" used to leak
  // English into an otherwise Arabic sentence).
  const resolved: MessageParams = {
    ...params,
    routeName: params.routeName || fallbackBusName(language),
    studentName: params.studentName || fallbackChildName(language),
    busName: params.busName || fallbackOtherBusName(language),
    subject: params.subject || FALLBACKS.subject[language],
  };
  const text = fill(phrase[language], resolved);
  return emoji ? `${emoji} ${text}` : text;
}

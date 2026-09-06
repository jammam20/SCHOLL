import { initializeApp } from "firebase-admin/app";
import { getDatabase } from "firebase-admin/database";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import {
  onDocumentUpdated,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { onValueWritten } from "firebase-functions/v2/database";

initializeApp();
const db = getFirestore();

// Parent/driver self-registration and admin approval used to be callables
// here, but that meant no one could sign up or get approved at all unless
// this project was on Firebase's paid Blaze plan. They're now handled
// client-side instead:
//  - sign-up: FirebaseAuthRepository.registerParent/registerDriver in the
//    parent/driver apps, validated by firestore.rules'
//    isPendingSelfServeDoc (self-owned, 'pending', never role:'admin').
//  - approve/suspend/reject: DriversRepository/ParentsRepository in the
//    admin app, validated by the `members/{uid}` update rule (admin-only,
//    restricted to the status/isActive fields).

// ---------------------------------------------------------------------------
// RTDB authorization mirror
// ---------------------------------------------------------------------------

/// Realtime Database security rules can't read Firestore documents, so they
/// have no way to evaluate the same `isActiveMember(schoolId)` check
/// firestore.rules uses everywhere — the live-location node previously had
/// to fall back to "any signed-in user", which let a member of one school
/// read (and, in principle, write to an unclaimed path in) another school's
/// live bus location. This mirrors the one fact RTDB's rules actually need —
/// "is this uid an active, approved member of this school" — into
/// `authorizedSchools/{uid}/{schoolId}` on every membership write, so
/// database.rules.json can check it directly via `root.child(...)` with no
/// propagation delay (unlike Firebase Auth custom claims, which only take
/// effect after the client's next token refresh).
export const syncSchoolMembership = onDocumentWritten(
  "schools/{schoolId}/members/{uid}",
  async (event) => {
    const { schoolId, uid } = event.params;
    const after = event.data?.after.data();
    const isAuthorized = after?.isActive === true && after?.status === "approved";

    const ref = getDatabase().ref(`authorizedSchools/${uid}/${schoolId}`);
    if (isAuthorized) {
      await ref.set(true);
    } else {
      await ref.remove();
    }
  },
);

// Mirrors TripStatus.canTransitionTo in
// packages/school_shared/lib/src/enums/trip_status.dart — keep the two in
// sync if the state machine changes.
const TRIP_STATUS_TRANSITIONS: Record<string, string[]> = {
  scheduled: ["starting", "cancelled"],
  starting: ["active", "cancelled"],
  active: ["paused", "completed", "emergency"],
  paused: ["active", "cancelled", "emergency"],
  emergency: ["completed", "cancelled"],
  completed: [],
  cancelled: [],
};

// RETIRED — superseded by TripsRepository.updateStatus's direct Firestore
// transaction in the driver app (validated the same way, against
// isValidTripTransition in firestore.rules) and by TripsRepository.updateStatus
// in the admin app. No client code calls this callable any more. Kept only
// for history; intentionally excluded from `firebase deploy --only functions`
// (see the deploy command in the Cloud Functions status section of the audit
// report) so it isn't deployed alongside the functions that are actually used.
export const updateTripStatus = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const schoolId = String(request.data?.schoolId ?? "").trim();
  const tripId = String(request.data?.tripId ?? "").trim();
  const nextStatus = String(request.data?.status ?? "").trim();

  if (!schoolId || !tripId || !(nextStatus in TRIP_STATUS_TRANSITIONS)) {
    throw new HttpsError(
      "invalid-argument",
      "schoolId, tripId and a valid status are required.",
    );
  }

  const callerUid = request.auth.uid;
  const tripRef = db
    .collection("schools")
    .doc(schoolId)
    .collection("trips")
    .doc(tripId);
  const callerMemberRef = db
    .collection("schools")
    .doc(schoolId)
    .collection("members")
    .doc(callerUid);

  const [trip, callerMember] = await Promise.all([
    tripRef.get(),
    callerMemberRef.get(),
  ]);

  if (!trip.exists) {
    throw new HttpsError("not-found", "Trip was not found.");
  }

  const tripData = trip.data();
  const callerData = callerMember.data();

  const isAssignedDriver = tripData?.driverId === callerUid;
  const isActiveSchoolAdmin =
    callerMember.exists &&
    callerData?.role === "admin" &&
    callerData?.status === "approved" &&
    callerData?.isActive === true;

  if (!isAssignedDriver && !isActiveSchoolAdmin) {
    throw new HttpsError(
      "permission-denied",
      "Only the assigned driver or a school administrator can update this trip.",
    );
  }

  const currentStatus = String(tripData?.status ?? "scheduled");
  const allowedNext = TRIP_STATUS_TRANSITIONS[currentStatus] ?? [];
  if (!allowedNext.includes(nextStatus)) {
    throw new HttpsError(
      "failed-precondition",
      `Cannot move a trip from '${currentStatus}' to '${nextStatus}'.`,
    );
  }

  await tripRef.set(
    {
      status: nextStatus,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return { success: true, tripId, status: nextStatus };
});

// RETIRED — superseded by StopOrderRepository.setStopOrder's direct
// Firestore transaction in the driver app. No client code calls this
// callable any more (drivers CAN write `stopOrder` directly now — see the
// trip update rule in firestore.rules). Kept only for history; intentionally
// excluded from deploy, same as updateTripStatus above.
export const setTripStopOrder = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const schoolId = String(request.data?.schoolId ?? "").trim();
  const tripId = String(request.data?.tripId ?? "").trim();
  const stopOrder = request.data?.stopOrder;

  if (
    !schoolId ||
    !tripId ||
    !Array.isArray(stopOrder) ||
    stopOrder.some((entry) => typeof entry !== "string")
  ) {
    throw new HttpsError(
      "invalid-argument",
      "schoolId, tripId and a stopOrder array of strings are required.",
    );
  }

  const callerUid = request.auth.uid;
  const tripRef = db
    .collection("schools")
    .doc(schoolId)
    .collection("trips")
    .doc(tripId);
  const callerMemberRef = db
    .collection("schools")
    .doc(schoolId)
    .collection("members")
    .doc(callerUid);

  const [trip, callerMember] = await Promise.all([
    tripRef.get(),
    callerMemberRef.get(),
  ]);
  if (!trip.exists) {
    throw new HttpsError("not-found", "Trip was not found.");
  }

  const tripData = trip.data();
  const callerData = callerMember.data();
  const isAssignedDriver = tripData?.driverId === callerUid;
  const isActiveSchoolAdmin =
    callerMember.exists &&
    callerData?.role === "admin" &&
    callerData?.status === "approved" &&
    callerData?.isActive === true;

  if (!isAssignedDriver && !isActiveSchoolAdmin) {
    throw new HttpsError(
      "permission-denied",
      "Only the assigned driver or a school administrator can reorder this trip's stops.",
    );
  }

  await tripRef.set(
    { stopOrder, updatedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );

  return { success: true };
});

// RETIRED — superseded by SchoolsRepository.updateLocation's direct write in
// the admin app. firestore.rules' schools/{schoolId} update rule already
// grants a school admin a write restricted to exactly
// ['latitude','longitude','updatedAt'], so this callable was never actually
// required; it just happened to be the only remaining write path in the app
// still routed through Functions, which is why it broke while Functions were
// undeployed. Kept only for history; intentionally excluded from deploy.
export const updateSchoolLocation = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const schoolId = String(request.data?.schoolId ?? "").trim();
  const latitude = Number(request.data?.latitude);
  const longitude = Number(request.data?.longitude);

  if (!schoolId || !Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    throw new HttpsError(
      "invalid-argument",
      "schoolId, latitude and longitude are required.",
    );
  }

  const callerUid = request.auth.uid;
  const memberSnap = await db
    .collection("schools")
    .doc(schoolId)
    .collection("members")
    .doc(callerUid)
    .get();
  const memberData = memberSnap.data();

  const isActiveSchoolAdmin =
    memberSnap.exists &&
    memberData?.role === "admin" &&
    memberData?.status === "approved" &&
    memberData?.isActive === true;

  if (!isActiveSchoolAdmin) {
    throw new HttpsError(
      "permission-denied",
      "Only an active school administrator can update the school's location.",
    );
  }

  await db.collection("schools").doc(schoolId).set(
    { latitude, longitude, updatedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );

  return { success: true };
});

// ---------------------------------------------------------------------------
// Push notifications
// ---------------------------------------------------------------------------

/// Great-circle distance between two coordinates, in meters. Mirrors
/// packages/school_shared/lib/src/utils/geo.dart — keep the two in sync.
function haversineMeters(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const earthRadiusMeters = 6371000;
  const degToRad = (degrees: number) => degrees * (Math.PI / 180);
  const dLat = degToRad(lat2 - lat1);
  const dLng = degToRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(degToRad(lat1)) *
      Math.cos(degToRad(lat2)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return earthRadiusMeters * c;
}

/// A parent's notification choices from the settings screen in the parent
/// app (updateNotificationPreferences callable). Missing/malformed fields
/// default to "on" (minutesBefore defaults to 10) so a parent who never
/// visited the settings screen still gets sensible alerts.
interface NotificationPrefs {
  tripStart: boolean;
  tripPause: boolean;
  tripEnd: boolean;
  arrival: boolean;
  minutesBefore: number; // 0 disables the "N minutes before" alert.
}

const DEFAULT_MINUTES_BEFORE = 10;

function prefsFromUserData(
  data: FirebaseFirestore.DocumentData | undefined,
): NotificationPrefs {
  const raw = (data?.notificationPrefs ?? {}) as Record<string, unknown>;
  return {
    tripStart: raw.tripStart !== false,
    tripPause: raw.tripPause !== false,
    tripEnd: raw.tripEnd !== false,
    arrival: raw.arrival !== false,
    minutesBefore:
      typeof raw.minutesBefore === "number" && raw.minutesBefore >= 0
        ? raw.minutesBefore
        : DEFAULT_MINUTES_BEFORE,
  };
}

async function tokensAndPrefsForUser(
  uid: string,
): Promise<{ tokens: string[]; prefs: NotificationPrefs }> {
  const snapshot = await db.collection("users").doc(uid).get();
  const data = snapshot.data();
  const rawTokens = data?.fcmTokens;
  const tokens = Array.isArray(rawTokens)
    ? rawTokens.filter(
        (token): token is string =>
          typeof token === "string" && token.length > 0,
      )
    : [];
  return { tokens, prefs: prefsFromUserData(data) };
}

/// Tokens (and the matching uids, for the in-app inbox — see
/// writeNotificationRecords) for every one of `uids` who has `prefKey`
/// enabled (or hasn't customized it, since prefs default to "on").
async function tokensForUidsWithPref(
  uids: string[],
  prefKey: keyof Omit<NotificationPrefs, "minutesBefore">,
): Promise<{ tokens: string[]; uids: string[] }> {
  const uniqueUids = [...new Set(uids)].filter((uid) => uid.length > 0);
  const tokens = new Set<string>();
  const matchedUids: string[] = [];
  for (const uid of uniqueUids) {
    const { tokens: userTokens, prefs } = await tokensAndPrefsForUser(uid);
    if (prefs[prefKey]) {
      userTokens.forEach((token) => tokens.add(token));
      matchedUids.push(uid);
    }
  }
  return { tokens: [...tokens], uids: matchedUids };
}

/// Writes one in-app inbox entry (`users/{uid}/notifications/{id}`) per
/// recipient, alongside the FCM push — this is what gives the "Smart
/// Notifications" feature a durable, readable history instead of only a
/// transient push a user could miss. Best-effort: a failed inbox write
/// never blocks or fails the push it accompanies.
async function writeNotificationRecords(
  uids: string[],
  schoolId: string,
  type: string,
  title: string,
  body: string,
  extra?: { tripId?: string; busId?: string; studentId?: string; postId?: string },
): Promise<void> {
  const uniqueUids = [...new Set(uids)].filter((uid) => uid.length > 0);
  if (uniqueUids.length === 0) return;

  await Promise.all(
    uniqueUids.map((uid) =>
      db
        .collection("users")
        .doc(uid)
        .collection("notifications")
        .add({
          schoolId,
          type,
          title,
          body,
          read: false,
          createdAt: FieldValue.serverTimestamp(),
          ...(extra?.tripId ? { tripId: extra.tripId } : {}),
          ...(extra?.busId ? { busId: extra.busId } : {}),
          ...(extra?.studentId ? { studentId: extra.studentId } : {}),
          ...(extra?.postId ? { postId: extra.postId } : {}),
        })
        .catch((error) =>
          console.error(`Failed to write notification inbox entry for ${uid}`, error),
        ),
    ),
  );
}

async function parentIdsForRoute(
  schoolId: string,
  routeId: string,
): Promise<string[]> {
  if (!routeId) return [];

  const studentsSnap = await db
    .collection("schools")
    .doc(schoolId)
    .collection("students")
    .where("routeId", "==", routeId)
    .where("isActive", "==", true)
    .get();

  const parentIds: string[] = [];
  for (const doc of studentsSnap.docs) {
    const ids = doc.data().parentIds;
    if (Array.isArray(ids)) {
      parentIds.push(...ids.filter((id) => typeof id === "string"));
    }
  }

  return [...new Set(parentIds)];
}

async function fcmTokensForSchoolAdmins(schoolId: string): Promise<string[]> {
  const membersSnap = await db
    .collection("schools")
    .doc(schoolId)
    .collection("members")
    .where("role", "==", "admin")
    .where("status", "==", "approved")
    .get();

  const tokens = new Set<string>();
  for (const doc of membersSnap.docs) {
    const { tokens: userTokens } = await tokensAndPrefsForUser(doc.id);
    userTokens.forEach((token) => tokens.add(token));
  }
  return [...tokens];
}

/// FCM error codes that mean "this token will never work again" (app
/// uninstalled, token rotated out from under us, etc.) as opposed to a
/// transient failure — only these are worth scrubbing from `fcmTokens`.
const DEAD_TOKEN_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
  "messaging/invalid-argument",
]);

/// Removes a token that FCM has told us is permanently dead from whichever
/// user document still lists it — cheap (`array-contains`, single-field,
/// no composite index needed) and rare (only runs on a delivery failure),
/// so this isn't a normal-path cost.
async function forgetDeadToken(token: string): Promise<void> {
  const snap = await db
    .collection("users")
    .where("fcmTokens", "array-contains", token)
    .get();
  await Promise.all(
    snap.docs.map((doc) =>
      doc.ref.update({ fcmTokens: FieldValue.arrayRemove(token) }),
    ),
  );
}

/// Sends a best-effort push notification to every token, with an optional
/// small data payload (e.g. `{type: 'emergency', schoolId, tripId}`) so the
/// client can decide where a tap on the notification should navigate.
/// Individual token failures are inspected: a permanently-dead token is
/// scrubbed from `users/{uid}.fcmTokens` so it stops being sent to (and
/// stops silently costing a doomed API call) on every future notification;
/// anything else is swallowed — this is a fire-and-forget alert, not a
/// critical operation worth retrying or failing the triggering write over.
async function sendPushNotification(
  tokens: string[],
  title: string,
  body: string,
  data?: Record<string, string>,
): Promise<void> {
  if (tokens.length === 0) return;

  // sendEachForMulticast caps out at 500 tokens per call.
  const chunkSize = 500;
  for (let i = 0; i < tokens.length; i += chunkSize) {
    const chunk = tokens.slice(i, i + chunkSize);
    try {
      const result = await getMessaging().sendEachForMulticast({
        tokens: chunk,
        notification: { title, body },
        data,
      });
      const deadTokens = result.responses
        .map((response, index) =>
          !response.success && DEAD_TOKEN_CODES.has(response.error?.code ?? "")
            ? chunk[index]
            : null,
        )
        .filter((token): token is string => token !== null);
      await Promise.all(deadTokens.map(forgetDeadToken));
    } catch (error) {
      console.error("Failed to send push notification chunk", error);
    }
  }
}

const TRIP_STATUS_NOTIFICATIONS: Record<
  string,
  { prefKey: keyof Omit<NotificationPrefs, "minutesBefore">; body: string }
> = {
  starting: { prefKey: "tripStart", body: "is starting its route" },
  paused: { prefKey: "tripPause", body: "has paused" },
  completed: { prefKey: "tripEnd", body: "has completed its trip" },
  cancelled: { prefKey: "tripEnd", body: "trip was cancelled" },
};

/// Notifies parents (filtered by their own start/pause/end preference) and,
/// on an emergency, admins too — emergencies always send regardless of
/// preferences. Also resets the per-trip "already notified" bookkeeping
/// used by [onDriverLocationWritten] whenever a trip restarts.
export const onTripStatusChanged = onDocumentUpdated(
  "schools/{schoolId}/trips/{tripId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || before.status === after.status) return;

    const { schoolId, tripId } = event.params;
    const status = String(after.status ?? "");
    const routeId = String(after.routeId ?? "");
    const routeName = String(after.routeName ?? "Your bus");

    if (status === "starting") {
      await getDatabase()
        .ref(`schools/${schoolId}/trips/${tripId}/notifyState`)
        .set(null);
    }

    if (status === "emergency") {
      const parentIds = await parentIdsForRoute(schoolId, routeId);
      const adminUids = await schoolAdminUids(schoolId);
      const tokens = new Set(await fcmTokensForSchoolAdmins(schoolId));
      for (const uid of parentIds) {
        const { tokens: userTokens } = await tokensAndPrefsForUser(uid);
        userTokens.forEach((token) => tokens.add(token));
      }
      const body = `⚠️ ${routeName} reported an emergency.`;
      await sendPushNotification([...tokens], "School Bus", body, {
        type: "emergency",
        schoolId,
        tripId,
      });
      await writeNotificationRecords(
        [...adminUids, ...parentIds],
        schoolId,
        "emergency",
        "School Bus",
        body,
        { tripId },
      );
      return;
    }

    const notification = TRIP_STATUS_NOTIFICATIONS[status];
    if (!notification) return;

    const parentIds = await parentIdsForRoute(schoolId, routeId);
    const { tokens, uids } = await tokensForUidsWithPref(
      parentIds,
      notification.prefKey,
    );
    const body = `🚌 ${routeName} ${notification.body}.`;
    await sendPushNotification(tokens, "School Bus", body, {
      type: "trip",
      schoolId,
      tripId,
    });
    await writeNotificationRecords(uids, schoolId, "trip", "School Bus", body, {
      tripId,
    });
  },
);

async function schoolAdminUids(schoolId: string): Promise<string[]> {
  const membersSnap = await db
    .collection("schools")
    .doc(schoolId)
    .collection("members")
    .where("role", "==", "admin")
    .where("status", "==", "approved")
    .get();
  return membersSnap.docs.map((doc) => doc.id);
}

/// Notifies the specific student's own parents (not the whole route) the
/// moment they're marked boarded or dropped off — Feature: Smart
/// Notifications' "Student boarded"/"Student dropped off" event types,
/// Feature: Student Ridership's own boardedStudents/droppedOffStudents
/// arrays as the single source of truth for "did this already happen"
/// (comparing before/after here, rather than a separate per-student flag,
/// so this can never drift from what the manifest itself shows).
export const onTripBoardingChanged = onDocumentUpdated(
  "schools/{schoolId}/trips/{tripId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const { schoolId, tripId } = event.params;
    const routeName = String(after.routeName ?? "Your bus");

    const beforeBoarded = new Set<string>(
      Array.isArray(before.boardedStudents) ? before.boardedStudents : [],
    );
    const afterBoarded = new Set<string>(
      Array.isArray(after.boardedStudents) ? after.boardedStudents : [],
    );
    const beforeDropped = new Set<string>(
      Array.isArray(before.droppedOffStudents) ? before.droppedOffStudents : [],
    );
    const afterDropped = new Set<string>(
      Array.isArray(after.droppedOffStudents) ? after.droppedOffStudents : [],
    );

    const newlyBoarded = [...afterBoarded].filter((id) => !beforeBoarded.has(id));
    const newlyDropped = [...afterDropped].filter((id) => !beforeDropped.has(id));
    if (newlyBoarded.length === 0 && newlyDropped.length === 0) return;

    const studentIds = [...newlyBoarded, ...newlyDropped];
    const studentsSnap = await db.getAll(
      ...studentIds.map((id) =>
        db.collection("schools").doc(schoolId).collection("students").doc(id),
      ),
    );

    for (const snap of studentsSnap) {
      if (!snap.exists) continue;
      const student = snap.data()!;
      const parentIds: string[] = Array.isArray(student.parentIds)
        ? student.parentIds.filter((id: unknown): id is string => typeof id === "string")
        : [];
      if (parentIds.length === 0) continue;

      const studentName = String(student.name ?? "Your child");
      const isBoarded = newlyBoarded.includes(snap.id);
      const body = isBoarded
        ? `✅ ${studentName} boarded the ${routeName} bus.`
        : `🏫 ${studentName} was dropped off from the ${routeName} bus.`;

      const tokens = new Set<string>();
      for (const uid of parentIds) {
        const { tokens: userTokens } = await tokensAndPrefsForUser(uid);
        userTokens.forEach((token) => tokens.add(token));
      }
      await sendPushNotification([...tokens], "School Bus", body, {
        type: isBoarded ? "student_boarded" : "student_dropped_off",
        schoolId,
        tripId,
      });
      await writeNotificationRecords(
        parentIds,
        schoolId,
        isBoarded ? "student_boarded" : "student_dropped_off",
        "School Bus",
        body,
        { tripId, studentId: snap.id },
      );
    }
  },
);

/// Notifies affected parents (and, for a driver swap, the newly assigned
/// driver) when an admin reassigns a trip's bus or driver — Feature:
/// Dynamic Route/Last-Minute Changes' "notifications to relevant users"
/// requirement, and Feature: Smart Notifications' "Bus changed" event type.
/// The audit-preserving ReassignmentRecord itself is written by the admin
/// client directly (see firestore.rules' trips/{tripId}/reassignments
/// rule) — this function only reacts to the resulting trip-document change
/// to notify people, mirroring how onTripStatusChanged only reacts to
/// (never itself decides) a status change.
export const onTripAssignmentChanged = onDocumentUpdated(
  "schools/{schoolId}/trips/{tripId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (before.busId === after.busId && before.driverId === after.driverId) return;

    const { schoolId, tripId } = event.params;
    const routeId = String(after.routeId ?? "");
    const routeName = String(after.routeName ?? "Your bus");
    const busChanged = before.busId !== after.busId;
    const driverChanged = before.driverId !== after.driverId;

    const parts: string[] = [];
    if (busChanged) parts.push(`bus changed to ${String(after.busName ?? "a different bus")}`);
    if (driverChanged) parts.push("driver changed");
    const body = `🚍 ${routeName}: ${parts.join(", ")}.`;

    const parentIds = await parentIdsForRoute(schoolId, routeId);
    const tokens = new Set<string>();
    for (const uid of parentIds) {
      const { tokens: userTokens } = await tokensAndPrefsForUser(uid);
      userTokens.forEach((token) => tokens.add(token));
    }
    const notifyUids = [...parentIds];
    if (driverChanged && typeof after.driverId === "string" && after.driverId) {
      const { tokens: driverTokens } = await tokensAndPrefsForUser(after.driverId);
      driverTokens.forEach((token) => tokens.add(token));
      notifyUids.push(after.driverId);
    }

    await sendPushNotification([...tokens], "School Bus", body, {
      type: "bus_changed",
      schoolId,
      tripId,
    });
    await writeNotificationRecords(notifyUids, schoolId, "bus_changed", "School Bus", body, {
      tripId,
    });
  },
);

// ---------------------------------------------------------------------------
// Real (road-following) route lines
// ---------------------------------------------------------------------------

// The same key already embedded in every app's web/index.html for the Maps
// JavaScript SDK (apps/*/web/index.html) — confirmed to also serve the
// Directions API on this project, so this reuses it rather than
// provisioning a second one.
const DIRECTIONS_API_KEY = "AIzaSyD8qnYXkPuq3gEjVgPPC3pfjBaVmeYGcow";

const SCHOOL_STOP_SENTINEL = "__school__";

/// Decodes a Google-encoded polyline string into plain points — the
/// standard algorithm (Directions API docs §Polyline), reimplemented here
/// rather than pulling in a package for one function.
function decodePolyline(encoded: string): { lat: number; lng: number }[] {
  const points: { lat: number; lng: number }[] = [];
  let index = 0;
  let lat = 0;
  let lng = 0;

  while (index < encoded.length) {
    let shift = 0;
    let result = 0;
    let b: number;
    do {
      b = encoded.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += result & 1 ? ~(result >> 1) : result >> 1;

    shift = 0;
    result = 0;
    do {
      b = encoded.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += result & 1 ? ~(result >> 1) : result >> 1;

    points.push({ lat: lat / 1e5, lng: lng / 1e5 });
  }
  return points;
}

/// Asks the Directions API for the actual road path through `points` in
/// order — `stopOrder` is already the driver's real sequence, so these are
/// passed as plain waypoints (no `optimize:true`) rather than letting
/// Directions reorder them. Returns `null` on anything short of a usable
/// route (no path exists, API error, fewer than two points) so the caller
/// can fall back to a straight line instead of erasing a working one.
async function fetchRoutePolyline(
  points: { lat: number; lng: number }[],
): Promise<{ lat: number; lng: number }[] | null> {
  if (points.length < 2) return null;

  const origin = points[0];
  const destination = points[points.length - 1];
  const waypoints = points.slice(1, -1);
  const params = new URLSearchParams({
    origin: `${origin.lat},${origin.lng}`,
    destination: `${destination.lat},${destination.lng}`,
    key: DIRECTIONS_API_KEY,
  });
  if (waypoints.length > 0) {
    params.set("waypoints", waypoints.map((p) => `${p.lat},${p.lng}`).join("|"));
  }

  try {
    const response = await fetch(
      `https://maps.googleapis.com/maps/api/directions/json?${params.toString()}`,
    );
    const data = (await response.json()) as {
      status: string;
      routes?: { overview_polyline?: { points?: string } }[];
    };
    if (data.status !== "OK" || !data.routes?.length) {
      console.warn("Directions API returned no route", data.status);
      return null;
    }
    const encoded = data.routes[0].overview_polyline?.points;
    return encoded ? decodePolyline(encoded) : null;
  } catch (error) {
    console.error("Directions API call failed", error);
    return null;
  }
}

/// Recomputes a trip's `routePolyline` (Feature: real route lines) every
/// time its `stopOrder` actually changes — the initial nearest-neighbor
/// computation when a trip starts, and any manual driver reorder after
/// that. Every map screen (parent/admin/driver) reads this one shared
/// field rather than each calling Directions itself, so the three never
/// disagree and a trip's route is computed exactly once per change instead
/// of three times.
///
/// Resolves each stop id to a coordinate the same way the driver app's own
/// StopOrderRepository.computeInitialOrder does client-side — a student's
/// pickup point, or the school itself for the sentinel stop — then writes
/// the result back onto the same trip document. That write's own
/// `stopOrder` is unchanged, so the guard below stops this from
/// retriggering itself.
export const onTripStopOrderRouted = onDocumentWritten(
  "schools/{schoolId}/trips/{tripId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after || after.status === "cancelled") return;

    const beforeOrder = Array.isArray(before?.stopOrder) ? before?.stopOrder : [];
    const afterOrder: string[] = Array.isArray(after.stopOrder) ? after.stopOrder : [];
    if (afterOrder.length < 2) return;
    if (JSON.stringify(beforeOrder) === JSON.stringify(afterOrder)) return;

    const { schoolId } = event.params;
    const schoolSnap = await db.collection("schools").doc(schoolId).get();
    const school = schoolSnap.data();
    const schoolLat = typeof school?.latitude === "number" ? school.latitude : null;
    const schoolLng = typeof school?.longitude === "number" ? school.longitude : null;

    const studentIds = afterOrder.filter((id) => id !== SCHOOL_STOP_SENTINEL);
    const studentDocs = studentIds.length
      ? await db.getAll(
          ...studentIds.map((id) =>
            db.collection("schools").doc(schoolId).collection("students").doc(id),
          ),
        )
      : [];
    const studentPoints = new Map<string, { lat: number; lng: number }>();
    for (const doc of studentDocs) {
      const data = doc.data();
      const lat = typeof data?.latitude === "number" ? data.latitude : null;
      const lng = typeof data?.longitude === "number" ? data.longitude : null;
      if (lat !== null && lng !== null) studentPoints.set(doc.id, { lat, lng });
    }

    const points: { lat: number; lng: number }[] = [];
    for (const id of afterOrder) {
      if (id === SCHOOL_STOP_SENTINEL) {
        if (schoolLat !== null && schoolLng !== null) {
          points.push({ lat: schoolLat, lng: schoolLng });
        }
        continue;
      }
      const point = studentPoints.get(id);
      if (point) points.push(point);
    }

    const polyline = await fetchRoutePolyline(points);
    await event.data!.after.ref.update({ routePolyline: polyline ?? [] });
  },
);

/// A school-wide (or audience-scoped) broadcast an admin sends from the
/// admin app — Feature: Smart Notifications' "School message" event type.
/// Written by the admin client to `schools/{schoolId}/messages/{id}` (see
/// firestore.rules); this function only fans it out as a push + inbox
/// entries, exactly like every other event type here.
export const onSchoolMessageCreated = onDocumentWritten(
  "schools/{schoolId}/messages/{messageId}",
  async (event) => {
    if (!event.data?.after.exists || event.data.before.exists) return; // create-only

    const { schoolId } = event.params;
    const message = event.data.after.data()!;
    const title = String(message.title ?? "School Bus");
    const body = String(message.body ?? "");
    const audience = String(message.audience ?? "all");
    if (!body) return;

    const membersQuery = db
      .collection("schools")
      .doc(schoolId)
      .collection("members")
      .where("status", "==", "approved")
      .where("isActive", "==", true);
    const membersSnap =
      audience === "all"
        ? await membersQuery.get()
        : await membersQuery.where("role", "==", audience === "parents" ? "parent" : "driver").get();

    const uids = membersSnap.docs.map((doc) => doc.id);
    const tokens = new Set<string>();
    for (const uid of uids) {
      const { tokens: userTokens } = await tokensAndPrefsForUser(uid);
      userTokens.forEach((token) => tokens.add(token));
    }
    await sendPushNotification([...tokens], title, body, {
      type: "school_message",
      schoolId,
    });
    await writeNotificationRecords(uids, schoolId, "school_message", title, body);
  },
);

/// Watches each trip's live GPS location and, for every student on the
/// route (and the school itself, as the fixed final stop), sends that
/// student's parents a personalized alert: an "arriving" notification once
/// the bus is within [PROXIMITY_METERS], and — independently, per parent,
/// respecting each parent's own `minutesBefore` setting — a "bus is about N
/// minutes away" heads-up. `notifyState` (reset whenever a trip (re)starts,
/// see [onTripStatusChanged]) tracks what's already been sent so nothing
/// repeats within a trip.
export const onDriverLocationWritten = onValueWritten(
  "schools/{schoolId}/trips/{tripId}/location",
  async (event) => {
    const after = event.data.after.val();
    if (!after) return;

    const latitude = Number(after.latitude);
    const longitude = Number(after.longitude);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return;

    const { schoolId, tripId } = event.params;

    const tripSnap = await db
      .collection("schools")
      .doc(schoolId)
      .collection("trips")
      .doc(tripId)
      .get();
    if (!tripSnap.exists) return;

    const trip = tripSnap.data()!;
    if (trip.status !== "active" && trip.status !== "starting") return;

    const routeId = String(trip.routeId ?? "");
    const routeName = String(trip.routeName ?? "Your bus");

    const speed = Number(after.speed);
    const effectiveSpeedMetersPerSecond =
      Number.isFinite(speed) && speed > 1.5 ? speed : 6;

    const PROXIMITY_METERS = 250;

    const notifyStateRef = getDatabase().ref(
      `schools/${schoolId}/trips/${tripId}/notifyState`,
    );
    const notifyStateSnap = await notifyStateRef.get();
    const notifyState = (notifyStateSnap.val() ?? {}) as {
      arrived?: Record<string, boolean>;
      preArrival?: Record<string, Record<string, boolean>>;
    };
    const arrivedIds = new Set(Object.keys(notifyState.arrived ?? {}));
    const preArrivalNotified = notifyState.preArrival ?? {};

    const updates: Record<string, unknown> = {};

    const studentsSnap = routeId
      ? await db
          .collection("schools")
          .doc(schoolId)
          .collection("students")
          .where("routeId", "==", routeId)
          .where("isActive", "==", true)
          .get()
      : null;

    for (const doc of studentsSnap?.docs ?? []) {
      const student = doc.data();
      const lat = Number(student.latitude);
      const lng = Number(student.longitude);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) continue;

      const parentIds: string[] = Array.isArray(student.parentIds)
        ? student.parentIds.filter(
            (id: unknown): id is string => typeof id === "string",
          )
        : [];
      if (parentIds.length === 0) continue;

      const distance = haversineMeters(latitude, longitude, lat, lng);
      const etaMinutes = distance / effectiveSpeedMetersPerSecond / 60;
      const studentName = String(student.name ?? "your child");

      if (!arrivedIds.has(doc.id) && distance <= PROXIMITY_METERS) {
        const { tokens, uids } = await tokensForUidsWithPref(parentIds, "arrival");
        const body = `🚌 ${routeName} bus is arriving at ${studentName}'s pickup point.`;
        await sendPushNotification(tokens, "Bus arriving", body, {
          type: "trip",
          schoolId,
          tripId,
        });
        await writeNotificationRecords(uids, schoolId, "trip", "Bus arriving", body, {
          tripId,
          studentId: doc.id,
        });
        updates[`arrived/${doc.id}`] = true;
        arrivedIds.add(doc.id);
      }

      for (const parentUid of parentIds) {
        if (preArrivalNotified[doc.id]?.[parentUid]) continue;

        const { tokens, prefs } = await tokensAndPrefsForUser(parentUid);
        if (prefs.minutesBefore > 0 && etaMinutes <= prefs.minutesBefore) {
          const body =
            `🚌 ${routeName} bus is about ` +
            `${Math.max(1, Math.round(etaMinutes))} min from ${studentName}.`;
          await sendPushNotification(tokens, "Bus on the way", body, {
            type: "trip",
            schoolId,
            tripId,
          });
          await writeNotificationRecords([parentUid], schoolId, "trip", "Bus on the way", body, {
            tripId,
            studentId: doc.id,
          });
          updates[`preArrival/${doc.id}/${parentUid}`] = true;
        }
      }
    }

    if (!arrivedIds.has("__school__")) {
      const schoolSnap = await db.collection("schools").doc(schoolId).get();
      const school = schoolSnap.data();
      const schoolLat = Number(school?.latitude);
      const schoolLng = Number(school?.longitude);

      if (Number.isFinite(schoolLat) && Number.isFinite(schoolLng)) {
        const distance = haversineMeters(
          latitude,
          longitude,
          schoolLat,
          schoolLng,
        );
        if (distance <= PROXIMITY_METERS) {
          const parentIds = await parentIdsForRoute(schoolId, routeId);
          const { tokens, uids } = await tokensForUidsWithPref(parentIds, "arrival");
          const body = `🚌 ${routeName} bus has arrived at school.`;
          await sendPushNotification(tokens, "Bus arrived", body, {
            type: "trip",
            schoolId,
            tripId,
          });
          await writeNotificationRecords(uids, schoolId, "trip", "Bus arrived", body, {
            tripId,
          });
          updates["arrived/__school__"] = true;
        }
      }
    }

    if (Object.keys(updates).length > 0) {
      await notifyStateRef.update(updates);
    }

    await evaluateRouteDeviation({
      schoolId,
      tripId,
      trip,
      busLatitude: latitude,
      busLongitude: longitude,
      studentsSnap,
    });
  },
);

// ---------------------------------------------------------------------------
// Route deviation detection
// ---------------------------------------------------------------------------

/// Mirrors packages/school_shared/lib/src/domain/deviation_engine.dart's
/// evaluateDeviation exactly (state machine, point-to-segment math, and the
/// "alert once per episode" behavior) — kept in sync deliberately the same
/// way TripStatus.canTransitionTo is duplicated between Dart and this file,
/// since Cloud Functions run TypeScript and can't import the Dart package.
type DeviationStatus = "normal" | "deviation_started" | "deviating" | "deviation_ended";

function degToRad(degrees: number): number {
  return degrees * (Math.PI / 180);
}

function distanceToSegmentMeters(
  pLat: number,
  pLng: number,
  aLat: number,
  aLng: number,
  bLat: number,
  bLng: number,
): number {
  const metersPerDegreeLat = 111320;
  const metersPerDegreeLng = 111320 * Math.cos(degToRad(pLat));

  const px = pLng * metersPerDegreeLng;
  const py = pLat * metersPerDegreeLat;
  const ax = aLng * metersPerDegreeLng;
  const ay = aLat * metersPerDegreeLat;
  const bx = bLng * metersPerDegreeLng;
  const by = bLat * metersPerDegreeLat;

  const dx = bx - ax;
  const dy = by - ay;
  const lengthSquared = dx * dx + dy * dy;

  let t = 0;
  if (lengthSquared !== 0) {
    t = ((px - ax) * dx + (py - ay) * dy) / lengthSquared;
    t = Math.max(0, Math.min(1, t));
  }

  const closestX = ax + t * dx;
  const closestY = ay + t * dy;
  const ddx = px - closestX;
  const ddy = py - closestY;
  return Math.sqrt(ddx * ddx + ddy * ddy);
}

function distanceToPathMeters(
  lat: number,
  lng: number,
  points: { latitude: number; longitude: number }[],
): number {
  if (points.length === 0) return 0;
  if (points.length === 1) {
    return haversineMeters(lat, lng, points[0].latitude, points[0].longitude);
  }
  let min = Infinity;
  for (let i = 0; i < points.length - 1; i++) {
    const d = distanceToSegmentMeters(
      lat,
      lng,
      points[i].latitude,
      points[i].longitude,
      points[i + 1].latitude,
      points[i + 1].longitude,
    );
    if (d < min) min = d;
  }
  return min;
}

const DEFAULT_DEVIATION_TOLERANCE_METERS = 400;

/// Evaluates the bus's current position against the trip's expected
/// stop-by-stop path (see DeviationRecord/SchoolRoute's own doc comments —
/// there is no separately-stored route polyline in this system, so the
/// trip's own stop order is the closest thing to "the expected route").
/// Persists the single live `deviation` doc per trip, appends a closed
/// history record to `routeDeviations` when an episode ends, and alerts
/// school admins exactly once per episode (on the NORMAL/DEVIATION_ENDED ->
/// DEVIATION_STARTED transition) — never on every subsequent GPS update
/// while still deviating.
async function evaluateRouteDeviation(args: {
  schoolId: string;
  tripId: string;
  trip: FirebaseFirestore.DocumentData;
  busLatitude: number;
  busLongitude: number;
  studentsSnap: FirebaseFirestore.QuerySnapshot | null;
}): Promise<void> {
  const { schoolId, tripId, trip, busLatitude, busLongitude, studentsSnap } = args;

  const stopOrder: string[] = Array.isArray(trip.stopOrder) ? trip.stopOrder : [];
  if (stopOrder.length < 2) return; // nothing to compare against yet

  const studentById = new Map<string, FirebaseFirestore.DocumentData>();
  for (const doc of studentsSnap?.docs ?? []) {
    studentById.set(doc.id, doc.data());
  }

  const schoolSnap = await db.collection("schools").doc(schoolId).get();
  const school = schoolSnap.data();

  const points: { latitude: number; longitude: number }[] = [];
  for (const stopId of stopOrder) {
    if (stopId === "__school__") {
      const lat = Number(school?.latitude);
      const lng = Number(school?.longitude);
      if (Number.isFinite(lat) && Number.isFinite(lng)) points.push({ latitude: lat, longitude: lng });
      continue;
    }
    const student = studentById.get(stopId);
    const lat = Number(student?.latitude);
    const lng = Number(student?.longitude);
    if (Number.isFinite(lat) && Number.isFinite(lng)) points.push({ latitude: lat, longitude: lng });
  }
  if (points.length < 2) return;

  let toleranceMeters = DEFAULT_DEVIATION_TOLERANCE_METERS;
  const routeId = String(trip.routeId ?? "");
  if (routeId) {
    const routeSnap = await db
      .collection("schools")
      .doc(schoolId)
      .collection("routes")
      .doc(routeId)
      .get();
    const tolerance = Number(routeSnap.data()?.deviationToleranceMeters);
    if (Number.isFinite(tolerance) && tolerance > 0) toleranceMeters = tolerance;
  }

  const deviationRef = db
    .collection("schools")
    .doc(schoolId)
    .collection("trips")
    .doc(tripId)
    .collection("deviation")
    .doc("current");
  const deviationSnap = await deviationRef.get();
  const previous = deviationSnap.data();
  const previousStatus = (previous?.status as DeviationStatus) ?? "normal";
  const previousMax = Number(previous?.maxDeviationMeters) || 0;

  const distance = distanceToPathMeters(busLatitude, busLongitude, points);
  const wasDeviating = previousStatus === "deviation_started" || previousStatus === "deviating";

  let status: DeviationStatus;
  let maxDeviation: number;
  let shouldAlert = false;
  let episodeEnded = false;

  if (distance <= toleranceMeters) {
    if (wasDeviating) {
      status = "deviation_ended";
      maxDeviation = previousMax;
      episodeEnded = true;
    } else {
      status = "normal";
      maxDeviation = 0;
    }
  } else if (wasDeviating) {
    status = "deviating";
    maxDeviation = Math.max(previousMax, distance);
  } else {
    status = "deviation_started";
    maxDeviation = distance;
    shouldAlert = true;
  }

  const now = FieldValue.serverTimestamp();
  const startedAt = wasDeviating ? previous?.startedAt ?? now : now;

  await deviationRef.set(
    {
      schoolId,
      tripId,
      busId: trip.busId ?? "",
      driverId: trip.driverId ?? "",
      routeId: routeId || null,
      status,
      startedAt: status === "normal" ? null : startedAt,
      endedAt: episodeEnded ? now : null,
      maxDeviationMeters: maxDeviation,
      currentDeviationMeters: distance,
    },
    { merge: false },
  );

  if (episodeEnded) {
    await db
      .collection("schools")
      .doc(schoolId)
      .collection("routeDeviations")
      .add({
        schoolId,
        tripId,
        busId: trip.busId ?? "",
        driverId: trip.driverId ?? "",
        routeId: routeId || null,
        status: "deviation_ended",
        startedAt,
        endedAt: now,
        maxDeviationMeters: maxDeviation,
        currentDeviationMeters: distance,
      });
  }

  if (shouldAlert) {
    const routeName = String(trip.routeName ?? "A bus");
    const body = `🛑 ${routeName} has deviated from its expected route.`;
    const adminUids = await schoolAdminUids(schoolId);
    const tokens = await fcmTokensForSchoolAdmins(schoolId);
    await sendPushNotification(tokens, "Route deviation", body, {
      type: "route_deviation",
      schoolId,
      tripId,
    });
    await writeNotificationRecords(adminUids, schoolId, "route_deviation", "Route deviation", body, {
      tripId,
    });
  }
}

// Saving notification preferences used to be a callable here, but that
// meant the settings screen silently did nothing unless this project was
// on Firebase's paid Blaze plan — the UI updated optimistically while the
// actual write never happened. It's now a direct write instead — see
// NotificationPrefsRepository.update in the parent app — restricted by
// firestore.rules to just the `notificationPrefs` field on the caller's
// own `users/{uid}` doc.

/// Registers (or refreshes) the calling user's FCM device token. Writes to
/// `users/{uid}` are otherwise blocked by firestore.rules and only ever done
/// server-side (see requestParentRegistration/setDriverMembershipStatus
/// above) — this callable follows the same pattern instead of loosening the
/// rules for client-writable tokens.
export const registerFcmToken = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const token = String(request.data?.token ?? "").trim();
  if (!token) {
    throw new HttpsError("invalid-argument", "A device token is required.");
  }

  await db.collection("users").doc(request.auth.uid).set(
    {
      fcmTokens: FieldValue.arrayUnion(token),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return { success: true };
});

/// Keeps a parent<->school message thread's summary fields (lastMessageAt/
/// lastMessagePreview/unreadByAdmin/unreadByParent) in sync with its
/// `messages` subcollection, and notifies whichever side didn't just send
/// the message — Feature: Parent-Driver communication, upgraded from a
/// one-shot message to a real continuing thread. Mirrors onSchoolMessageCreated's
/// create-only trigger shape.
export const onParentMessageCreated = onDocumentWritten(
  "schools/{schoolId}/parentRequests/{requestId}/messages/{messageId}",
  async (event) => {
    if (!event.data?.after.exists || event.data.before.exists) return; // create-only

    const { schoolId, requestId } = event.params;
    const message = event.data.after.data()!;
    const senderRole = String(message.senderRole ?? "");
    const text = String(message.text ?? "");
    if (!text) return;

    const threadRef = db
      .collection("schools")
      .doc(schoolId)
      .collection("parentRequests")
      .doc(requestId);
    const threadSnap = await threadRef.get();
    if (!threadSnap.exists) return;
    const thread = threadSnap.data()!;

    const preview = text.length > 120 ? `${text.slice(0, 120)}…` : text;
    const isFromParent = senderRole === "parent";

    await threadRef.update({
      lastMessageAt: FieldValue.serverTimestamp(),
      lastMessagePreview: preview,
      unreadByAdmin: isFromParent,
      unreadByParent: !isFromParent,
    });

    const subject = String(thread.subject ?? "your message");
    if (isFromParent) {
      const adminUids = await schoolAdminUids(schoolId);
      const tokens = await fcmTokensForSchoolAdmins(schoolId);
      const body = `💬 New message about ${subject}: ${preview}`;
      await sendPushNotification(tokens, "School Bus", body, {
        type: "parent_message",
        schoolId,
        tripId: requestId,
      });
      await writeNotificationRecords(adminUids, schoolId, "parent_message", "School Bus", body);
    } else {
      const parentUid = String(thread.parentUid ?? "");
      if (!parentUid) return;
      const { tokens } = await tokensAndPrefsForUser(parentUid);
      const body = `💬 Your school replied: ${preview}`;
      await sendPushNotification(tokens, "School Bus", body, {
        type: "parent_message",
        schoolId,
        tripId: requestId,
      });
      await writeNotificationRecords([parentUid], schoolId, "parent_message", "School Bus", body);
    }
  },
);

/// Notifies a community post's author when their post is hidden by
/// moderation (Feature: Parent Community) — the only status transition
/// that gets a push; restore/archive/delete don't, matching the user-
/// facing spec's own notification list. The author's uid is never on the
/// post document itself (see firestore.rules' own comment on why identity
/// lives only in the admin-only `authors` subcollection); this function
/// can still read it because Admin SDK writes bypass security rules
/// entirely — that's what makes a server-only lookup like this safe where
/// a client-side one would defeat the whole anonymity guarantee.
export const onCommunityPostStatusChanged = onDocumentUpdated(
  "schools/{schoolId}/communityPosts/{postId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (before.status === after.status || after.status !== "hidden") return;

    const { schoolId, postId } = event.params;
    const authorSnap = await db
      .collection("schools")
      .doc(schoolId)
      .collection("communityPosts")
      .doc(postId)
      .collection("authors")
      .doc("post")
      .get();
    const authorUid = String(authorSnap.data()?.authorUid ?? "");
    if (!authorUid) return;

    const { tokens } = await tokensAndPrefsForUser(authorUid);
    const body = "Your community post was hidden by your school's admin.";
    await sendPushNotification(tokens, "School Bus", body, {
      type: "community_post_hidden",
      schoolId,
      postId,
    });
    await writeNotificationRecords(
      [authorUid],
      schoolId,
      "community_post_hidden",
      "School Bus",
      body,
      { postId },
    );
  },
);

/// Notifies a post's author when the school admin replies to it (Feature:
/// Parent Community) — the one reply-side push this feature sends; a
/// parent's own comment never notifies anyone, matching how a post never
/// notifies other parents either. Create-only, and only for an admin's
/// reply (`isAdmin === true`) — a fellow parent's comment is exactly the
/// kind of activity this feature deliberately keeps quiet.
export const onCommunityCommentCreated = onDocumentWritten(
  "schools/{schoolId}/communityPosts/{postId}/comments/{commentId}",
  async (event) => {
    if (!event.data?.after.exists || event.data.before.exists) return; // create-only

    const comment = event.data.after.data()!;
    if (comment.isAdmin !== true) return;

    const { schoolId, postId } = event.params;
    const authorSnap = await db
      .collection("schools")
      .doc(schoolId)
      .collection("communityPosts")
      .doc(postId)
      .collection("authors")
      .doc("post")
      .get();
    const authorUid = String(authorSnap.data()?.authorUid ?? "");
    if (!authorUid) return;

    const text = String(comment.content ?? "");
    const preview = text.length > 120 ? `${text.slice(0, 120)}…` : text;
    const { tokens } = await tokensAndPrefsForUser(authorUid);
    const body = `🏫 Your school replied to your community post: ${preview}`;
    await sendPushNotification(tokens, "School Bus", body, {
      type: "community_admin_replied",
      schoolId,
      postId,
    });
    await writeNotificationRecords(
      [authorUid],
      schoolId,
      "community_admin_replied",
      "School Bus",
      body,
      { postId },
    );
  },
);

/// Notifies a report's own reporter once an admin marks it resolved
/// (Feature: Parent Community) — deliberately the only report-side push;
/// nothing ever notifies the *post's* author that they were reported, and
/// nothing tells one parent who reported them, matching this feature's
/// anonymity guarantee.
export const onCommunityReportResolved = onDocumentUpdated(
  "schools/{schoolId}/communityPosts/{postId}/reports/{reportId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (before.status === after.status || after.status !== "resolved") return;

    const { schoolId, postId } = event.params;
    const reporterUid = String(after.reporterUid ?? "");
    if (!reporterUid) return;

    const { tokens } = await tokensAndPrefsForUser(reporterUid);
    const body = "Your school reviewed the post you reported.";
    await sendPushNotification(tokens, "School Bus", body, {
      type: "community_report_resolved",
      schoolId,
      postId,
    });
    await writeNotificationRecords(
      [reporterUid],
      schoolId,
      "community_report_resolved",
      "School Bus",
      body,
      { postId },
    );
  },
);

// ---------------------------------------------------------------------------
// One-time migration
// ---------------------------------------------------------------------------

/// syncSchoolMembership (above) only mirrors a membership into
/// `authorizedSchools` going forward, on the *next* write to that member's
/// doc — any school/member that already existed before syncSchoolMembership
/// was deployed has no entry yet, and would be locked out of reading or
/// writing their own school's live bus location by the RTDB rules that
/// entry now gates. A system admin calls this once, after this phase
/// deploys, to backfill every currently-active-and-approved member; it's
/// safe to call more than once (each run just re-derives the same state).
export const backfillSchoolAuthorization = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const callerSnap = await db
    .collection("systemAdmins")
    .doc(request.auth.uid)
    .get();
  if (callerSnap.data()?.isActive !== true) {
    throw new HttpsError(
      "permission-denied",
      "Only a system administrator can run this.",
    );
  }

  const membersSnap = await db.collectionGroup("members").get();
  const rtdb = getDatabase();
  let authorized = 0;

  await Promise.all(
    membersSnap.docs.map(async (doc) => {
      const data = doc.data();
      const schoolId = doc.ref.parent.parent?.id;
      if (!schoolId) return;

      const ref = rtdb.ref(`authorizedSchools/${doc.id}/${schoolId}`);
      if (data.isActive === true && data.status === "approved") {
        await ref.set(true);
        authorized += 1;
      } else {
        await ref.remove();
      }
    }),
  );

  return { success: true, membersProcessed: membersSnap.size, authorized };
});

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

/// Tokens for every one of `uids` who has `prefKey` enabled (or hasn't
/// customized it, since prefs default to "on").
async function tokensForUidsWithPref(
  uids: string[],
  prefKey: keyof Omit<NotificationPrefs, "minutesBefore">,
): Promise<string[]> {
  const uniqueUids = [...new Set(uids)].filter((uid) => uid.length > 0);
  const tokens = new Set<string>();
  for (const uid of uniqueUids) {
    const { tokens: userTokens, prefs } = await tokensAndPrefsForUser(uid);
    if (prefs[prefKey]) {
      userTokens.forEach((token) => tokens.add(token));
    }
  }
  return [...tokens];
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
      const tokens = new Set(await fcmTokensForSchoolAdmins(schoolId));
      for (const uid of parentIds) {
        const { tokens: userTokens } = await tokensAndPrefsForUser(uid);
        userTokens.forEach((token) => tokens.add(token));
      }
      await sendPushNotification(
        [...tokens],
        "School Bus",
        `⚠️ ${routeName} reported an emergency.`,
        { type: "emergency", schoolId, tripId },
      );
      return;
    }

    const notification = TRIP_STATUS_NOTIFICATIONS[status];
    if (!notification) return;

    const parentIds = await parentIdsForRoute(schoolId, routeId);
    const tokens = await tokensForUidsWithPref(
      parentIds,
      notification.prefKey,
    );
    await sendPushNotification(
      tokens,
      "School Bus",
      `🚌 ${routeName} ${notification.body}.`,
      { type: "trip", schoolId, tripId },
    );
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
        const tokens = await tokensForUidsWithPref(parentIds, "arrival");
        await sendPushNotification(
          tokens,
          "Bus arriving",
          `🚌 ${routeName} bus is arriving at ${studentName}'s pickup point.`,
          { type: "trip", schoolId, tripId },
        );
        updates[`arrived/${doc.id}`] = true;
        arrivedIds.add(doc.id);
      }

      for (const parentUid of parentIds) {
        if (preArrivalNotified[doc.id]?.[parentUid]) continue;

        const { tokens, prefs } = await tokensAndPrefsForUser(parentUid);
        if (prefs.minutesBefore > 0 && etaMinutes <= prefs.minutesBefore) {
          await sendPushNotification(
            tokens,
            "Bus on the way",
            `🚌 ${routeName} bus is about ` +
              `${Math.max(1, Math.round(etaMinutes))} min from ${studentName}.`,
            { type: "trip", schoolId, tripId },
          );
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
          const tokens = await tokensForUidsWithPref(parentIds, "arrival");
          await sendPushNotification(
            tokens,
            "Bus arrived",
            `🚌 ${routeName} bus has arrived at school.`,
            { type: "trip", schoolId, tripId },
          );
          updates["arrived/__school__"] = true;
        }
      }
    }

    if (Object.keys(updates).length > 0) {
      await notifyStateRef.update(updates);
    }
  },
);

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

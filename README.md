# School Bus System

Production-oriented, multi-school Flutter + Firebase system for parents, drivers, school
administrators, and a platform-level super admin.

Firebase project: `sharlok-ef2b4` (Blaze plan).

## Monorepo structure

```
apps/
  school_parent        Parent app — children, live trip tracking, notifications
  school_driver        Driver app — trip lifecycle, boarding, stop order, emergencies, GPS
  school_admin         School admin app — people, fleet, trips, live ops, reports
  school_super_admin   Platform owner app — create schools, approve first admin
packages/
  school_shared        Framework-agnostic models, enums, and pure business-rule functions
functions/             Cloud Functions (TypeScript) — FCM sending, RTDB↔Firestore auth mirror
firebase/              firestore.rules, firestore.indexes.json, database.rules.json, storage.rules
```

This is a native **Dart/Flutter workspace** (see the `workspace:` field in the root
`pubspec.yaml`) — dependencies for all four apps and the shared package are resolved
**together, from the repository root**, into a single root `pubspec.lock`. There is no
`melos.yaml`; Melos is used only for its `melos exec` convenience scripts, defined directly
under the `melos:` key in the root `pubspec.yaml`.

Targets: **Android and Web** for all four apps. There is currently no iOS platform folder
for any app (out of scope until a future phase adds it).

---

## Setup on a new computer

### 1. Prerequisites

| Tool | Version used to build this repo | Notes |
|---|---|---|
| Flutter | 3.47.0 (stable channel) | Bundles Dart 3.13.0, which matches this repo's `sdk: ^3.13.0` constraint |
| Dart | 3.13.0 | Comes with the Flutter SDK above — no separate install needed |
| Node.js | 22.x | Required by `functions/package.json`'s `engines.node`. (Node 24 has also been used successfully against this codebase, but 22 is the pinned/supported version.) |
| npm | any recent version bundled with Node 22 | |
| Firebase CLI | 15.x (`npm install -g firebase-tools`) | Needed for `firebase deploy`, `firebase emulators:*` |
| Android Studio + Android SDK | any recent stable release | Needed to build/run the Android targets; also the easiest way to get an Android emulator |
| Java (JDK) | required only for the Firebase Emulator Suite | Not required to build/run the Flutter apps themselves |

Verify your setup with `flutter doctor`.

### 2. Clone the repository

```bash
git clone <your-fork-or-remote-url> school_bus_system
cd school_bus_system
```

### 3. Install Dart/Flutter dependencies (whole workspace, one command)

```bash
flutter pub get
```

Because this is a Dart workspace, running this **once at the repository root** resolves
dependencies for every app and the shared package. You do not need to run it separately
inside `apps/school_parent`, etc. (Melos also exposes this as `melos run get`, if you have
Melos installed globally — `dart pub global activate melos`.)

### 4. Firebase configuration

This repo already contains everything needed to talk to the `sharlok-ef2b4` Firebase
project — **you don't need to run `flutterfire configure` yourself** unless you're pointing
this codebase at a different Firebase project entirely:

- `apps/*/lib/firebase_options.dart` — per-platform `FirebaseOptions` (apiKey, appId,
  projectId, messagingSenderId, authDomain, databaseURL, storageBucket).
- `apps/{school_parent,school_admin,school_driver}/android/app/google-services.json` —
  the Android equivalent of the above.
- `.firebaserc` — maps the local Firebase CLI to project `sharlok-ef2b4`.
- `firebase.json`, `firebase/firestore.rules`, `firebase/firestore.indexes.json`,
  `firebase/database.rules.json`, `firebase/storage.rules` — deployable configuration.

> **Why these are safe to commit:** the `apiKey` values inside `firebase_options.dart` and
> `google-services.json` are public client identifiers, not secrets — they're the same
> thing you'd extract from any built APK or web bundle with a text editor. Firebase's own
> documentation is explicit about this. Actual authorization is enforced entirely by the
> security rules in `firebase/`, not by hiding these values. **What this repo does NOT
> contain, and never should:** a Firebase Admin SDK service account JSON, any
> `*-firebase-adminsdk-*.json` file, or a `GOOGLE_APPLICATION_CREDENTIALS` key — none of
> those are needed to build or run any of the four apps.

`school_super_admin` deliberately has no `google-services.json`/Android Firebase
registration of its own — it initializes Firebase in Dart using the same project's
Android/Web app IDs (see the comment at the top of its `firebase_options.dart`).

If you deploy Firebase config changes, you'll need to be logged in and targeting the right
project:

```bash
firebase login
firebase use sharlok-ef2b4
firebase deploy --only firestore:rules,firestore:indexes,database,storage
```

### 5. Google Maps API key (local setup required)

The Maps API key is **not committed** anywhere in this repo. You need your own key (Maps
SDK for Android + Maps JavaScript API enabled on it in the Google Cloud Console, restricted
to your package name/SHA-1 for Android and your dev origin for Web) and to configure it in
two places:

**Android** — copy the example file per app and fill in your key:

```bash
cp apps/school_parent/android/local.properties.example apps/school_parent/android/local.properties
cp apps/school_admin/android/local.properties.example  apps/school_admin/android/local.properties
cp apps/school_driver/android/local.properties.example  apps/school_driver/android/local.properties
```

Then edit each `local.properties` and set:

```properties
MAPS_API_KEY=your_real_key_here
```

(`local.properties` also needs the usual Flutter-managed `sdk.dir`/`flutter.sdk` lines —
these are normally added automatically the first time you open the project in an IDE or run
a Flutter command; the `.example` file only documents the one line you have to add
yourself.) `build.gradle.kts` reads this value at build time and injects it into
`AndroidManifest.xml`'s `com.google.android.geo.API_KEY` meta-data via a Gradle manifest
placeholder — the manifest itself never contains a real key.

**Web** — a static `web/index.html` can't read a local config file at build time the way
Gradle can, so for local web testing you need to paste your key directly into the
`<script src="https://maps.googleapis.com/maps/api/js?key=...">` tag in:
`apps/{school_parent,school_admin,school_driver}/web/index.html`. **Do not commit that
change** — if you do, `git status` will show it as a modified tracked file; revert it (or
just remember not to `git add` it) before pushing. Without a real key, the map still
renders — it just shows Google's own "for development purposes only" placeholder tiles
instead of real imagery.

`school_super_admin` doesn't use Google Maps and needs no key.

### 6. Running each app

Each app is Android/Web capable. From the repository root:

```bash
# Parent
flutter run -d chrome  --target apps/school_parent/lib/main.dart
flutter run -d android --target apps/school_parent/lib/main.dart

# Driver
flutter run -d chrome  --target apps/school_driver/lib/main.dart

# Admin
flutter run -d chrome  --target apps/school_admin/lib/main.dart

# Super Admin
flutter run -d chrome  --target apps/school_super_admin/lib/main.dart
```

Or `cd` into the specific app directory and run `flutter run -d <device>` without
`--target` (both work identically in a Dart workspace).

The very first super admin account cannot be created from any app UI by design — `allow
write: if false` on `systemAdmins/{uid}` in `firestore.rules` is unconditional. Seed it
once via the Firebase Console or Admin SDK: create the Auth user, then create a
`systemAdmins/{uid}` document with `{ isActive: true, name: "..." }`.

### 7. Cloud Functions

```bash
cd functions
npm install
npm run build      # compiles src/ (TypeScript) -> lib/ (gitignored)
```

Deployed functions (Blaze plan required — the project is already on Blaze):

```bash
firebase deploy --only "functions:syncSchoolMembership,functions:onTripStatusChanged,functions:onDriverLocationWritten,functions:registerFcmToken"
```

Three functions exist in `functions/src/index.ts` (`updateTripStatus`, `setTripStopOrder`,
`updateSchoolLocation`) but are marked `RETIRED` in source and deliberately **not**
deployed — every app now writes directly to Firestore for those operations, validated by
`firestore.rules`, instead of going through a callable. `backfillSchoolAuthorization` is a
one-time migration callable (see the comment above it in `index.ts`) — deployed, but only
needs to be invoked once, by a system admin, and only if this project already had approved
school memberships before the RTDB authorization mirror was introduced.

No secrets are required to build or deploy `functions/` beyond being logged in as a
Firebase project member via `firebase login`.

### 8. Firebase Emulators (optional, for local rule/function testing)

```bash
firebase emulators:start
```

Requires a Java runtime (JDK 11+) on your machine — the emulator suite is a Java
application under the hood. If you don't have Java installed, this step simply isn't
available to you locally; it does not block building or running the Flutter apps
themselves, which all talk to the real `sharlok-ef2b4` project directly.

### 9. Running tests

```bash
# Whole workspace pure-Dart tests
cd packages/school_shared && flutter test
cd apps/school_driver && flutter test
```

Only `packages/school_shared` and `apps/school_driver` currently have automated tests
(pure business-logic unit tests, no emulator required). `apps/school_admin`,
`apps/school_parent`, and `apps/school_super_admin` have no test coverage yet.

### 10. Static analysis

```bash
melos exec -- "flutter analyze"
```

(or run `flutter analyze` inside each of the 5 packages individually). This repository is
kept at zero analyzer issues across all packages.

---

## Security notes

- **Never commit**: a Firebase Admin SDK service account JSON, any real Google Maps API
  key inside `web/index.html`, `android/local.properties`, `android/key.properties`, or any
  keystore (`*.jks`/`*.keystore`). All of these are covered by `.gitignore`.
- **Safe to commit** (and required, for the project to build at all): `firebase_options.dart`,
  `google-services.json`, `.firebaserc`, `firebase.json`, and everything under `firebase/`.
  These identify the client to Firebase; they don't grant access to anything by themselves.
- Android release builds in all four apps currently sign with the **debug keystore**
  (`signingConfig = signingConfigs.getByName("debug")` in each `build.gradle.kts`, with an
  explicit `// TODO: Add your own signing config for the release build.`) — this is fine
  for development but must be replaced with a real keystore (kept out of git via
  `android/key.properties` + `*.jks`, already gitignored) before any real Play Store
  release.

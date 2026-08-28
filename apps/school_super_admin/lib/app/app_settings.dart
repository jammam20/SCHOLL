library;

/// `AppSettings` and `S` now live in `packages/school_shared` (and
/// `AppSettings` now persists across restarts via shared_preferences,
/// which this app's own previous copy did not) — see
/// `design-system/MASTER.md` "Theme architecture". Kept as a re-export so
/// existing `import 'app_settings.dart';` call sites in this app don't
/// need to change.
export 'package:school_shared/school_shared.dart' show AppSettings, S;

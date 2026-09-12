import 'package:geolocator/geolocator.dart';

/// Every state the driver's own live-GPS broadcast can be in — Production
/// hardening: previously [DriverTrackingRepository] had exactly two states
/// ("subscribed" / "not subscribed") with every failure inside the stream
/// silently swallowed (see the old `catch (_) {}` in `startTracking`). A
/// child-safety-adjacent feature failing without telling anyone is worse
/// than the feature itself failing, so every distinguishable failure mode
/// now has its own state the driver app can react to.
enum DriverTrackingStatus {
  /// No trip currently needs tracking, or it was just stopped
  /// (paused/completed/cancelled). The initial state.
  stopped,

  /// [DriverTrackingRepository.startTracking] is running its permission/
  /// service checks; no position has been read yet.
  starting,

  /// The position stream is live and the most recent RTDB write succeeded.
  tracking,

  /// `Geolocator.checkPermission()`/`requestPermission()` returned
  /// [LocationPermission.denied] — recoverable without leaving the app.
  permissionDenied,

  /// The permission was denied "don't ask again" — the OS will not show
  /// the prompt again; the driver must grant it from system settings.
  permissionPermanentlyDenied,

  /// `Geolocator.isLocationServiceEnabled()` returned false — the device's
  /// location service itself (not just this app's permission) is off.
  locationServiceDisabled,

  /// The position stream itself raised an error (a plugin/platform error,
  /// not a write failure) and could not be recovered after bounded retries.
  gpsError,

  /// The most recent RTDB write failed for a reason classified as
  /// connectivity (offline, timed out) rather than a Firebase-side
  /// rejection. The position stream itself is untouched — the next fix
  /// retries the write on its own.
  networkError,

  /// The most recent RTDB write failed for a non-connectivity reason (e.g.
  /// a rules rejection). Also non-fatal to the stream — retried on the
  /// next fix — but worth surfacing distinctly since, unlike a network
  /// blip, this will not necessarily resolve itself.
  firebaseWriteError,

  /// Tracking is supposed to be live (permission/service are fine, no
  /// stream error occurred) but no position has been read in over
  /// [DriverTrackingRepository.staleAfter] — the phone may have lost GPS
  /// signal, or the OS may have silently throttled the app.
  staleLocation,

  /// A write attempt is failing repeatedly (network or Firebase) but the
  /// position stream is still alive and still retrying on every fix.
  reconnecting,

  /// Emitted once, transitionally, the moment a prior failure (stale /
  /// reconnecting / gpsError) resolves back to a successful write — the UI
  /// shows this as a one-off "recovered" toast, then the next status the
  /// repository emits is [tracking].
  recovered,
}

/// True for every state where the driver app should show *some* visible
/// signal — as opposed to the two "everything is fine, say nothing" states
/// ([DriverTrackingStatus.tracking], [DriverTrackingStatus.stopped]) and the
/// purely-internal [DriverTrackingStatus.starting] transient.
extension DriverTrackingStatusX on DriverTrackingStatus {
  bool get isProblem => switch (this) {
    DriverTrackingStatus.permissionDenied ||
    DriverTrackingStatus.permissionPermanentlyDenied ||
    DriverTrackingStatus.locationServiceDisabled ||
    DriverTrackingStatus.gpsError ||
    DriverTrackingStatus.networkError ||
    DriverTrackingStatus.firebaseWriteError ||
    DriverTrackingStatus.staleLocation ||
    DriverTrackingStatus.reconnecting => true,
    DriverTrackingStatus.stopped ||
    DriverTrackingStatus.starting ||
    DriverTrackingStatus.tracking ||
    DriverTrackingStatus.recovered => false,
  };

  /// Whether the *position stream itself* is still expected to be alive in
  /// this state — as opposed to a state where nothing will recover it
  /// without the driver taking an action (granting a permission, enabling
  /// location services) or the app explicitly retrying.
  bool get streamIsAlive => switch (this) {
    DriverTrackingStatus.tracking ||
    DriverTrackingStatus.staleLocation ||
    DriverTrackingStatus.reconnecting ||
    DriverTrackingStatus.networkError ||
    DriverTrackingStatus.firebaseWriteError ||
    DriverTrackingStatus.recovered ||
    DriverTrackingStatus.starting => true,
    DriverTrackingStatus.stopped ||
    DriverTrackingStatus.permissionDenied ||
    DriverTrackingStatus.permissionPermanentlyDenied ||
    DriverTrackingStatus.locationServiceDisabled ||
    DriverTrackingStatus.gpsError => false,
  };
}

/// Maps a raw error from the position stream's `onError` (a
/// [PlatformException]-derived Geolocator exception, or anything else a
/// platform channel can throw) to the specific status it represents. A
/// pure function so this classification is unit-testable without a real
/// device/emulator — see `driver_tracking_status_test.dart`.
DriverTrackingStatus classifyPositionStreamError(Object error) {
  if (error is LocationServiceDisabledException) {
    return DriverTrackingStatus.locationServiceDisabled;
  }
  if (error is PermissionDeniedException) {
    return DriverTrackingStatus.permissionDenied;
  }
  return DriverTrackingStatus.gpsError;
}

/// Maps a raw error from the RTDB `.set()` write inside the position
/// listener to networkError vs. firebaseWriteError. Firebase plugin
/// exceptions carry a `code`/`message` rather than a typed hierarchy, so
/// this matches on the substrings both `firebase_database` and the
/// underlying platform layer are documented to use for connectivity
/// failures — anything else is treated as a (non-connectivity) write
/// rejection rather than guessed at.
DriverTrackingStatus classifyWriteError(Object error) {
  final text = error.toString().toLowerCase();
  const networkMarkers = [
    'network',
    'disconnect',
    'timed out',
    'timeout',
    'unavailable',
    'offline',
  ];
  if (networkMarkers.any(text.contains)) {
    return DriverTrackingStatus.networkError;
  }
  return DriverTrackingStatus.firebaseWriteError;
}

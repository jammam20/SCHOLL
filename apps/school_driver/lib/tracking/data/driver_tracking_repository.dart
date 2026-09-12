import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:geolocator/geolocator.dart';

import '../domain/driver_tracking_status.dart';

/// How often [DriverTrackingRepository]'s watchdog checks whether a
/// position has been read recently — deliberately much shorter than
/// [_defaultStaleAfter] so staleness is caught close to the threshold
/// rather than up to a whole cycle late.
const _defaultWatchdogInterval = Duration(seconds: 10);

/// No position read in this long while tracking should be live is reported
/// as [DriverTrackingStatus.staleLocation] — long enough that ordinary GPS
/// jitter (a few seconds between fixes given the 8s `intervalDuration`/10m
/// `distanceFilter` settings below) never trips it, short enough that a
/// genuinely lost signal is caught well within the shared ETA engine's own
/// 3-minute `staleGpsThreshold` that the admin/parent apps use to stop
/// treating a bus's last-known fix as live.
const _defaultStaleAfter = Duration(seconds: 45);

/// Beyond this much longer with still no position, the watchdog concludes
/// the stream itself has died (rather than just the phone briefly losing
/// signal) and attempts one bounded restart — see [_defaultMaxRestartAttempts].
const _defaultDeadStreamAfter = Duration(minutes: 2);

/// Caps the watchdog's own restart attempts so a genuinely broken
/// environment (permission silently revoked at the OS level with no error
/// ever delivered, a device with no GPS radio) settles into
/// [DriverTrackingStatus.gpsError] instead of retrying forever — see the
/// requirement to avoid an aggressive infinite retry loop.
const _defaultMaxRestartAttempts = 3;

class DriverTrackingRepository {
  DriverTrackingRepository({
    FirebaseDatabase? database,
    FirebaseAuth? auth,
    Future<bool> Function()? isLocationServiceEnabled,
    Future<LocationPermission> Function()? checkPermission,
    Future<LocationPermission> Function()? requestPermission,
    Stream<Position> Function(LocationSettings settings)? positionStream,
    String? Function()? currentDriverId,
    Future<void> Function(String schoolId, String tripId, Map<String, dynamic> data)?
    writeLocation,
    Duration? watchdogInterval,
    Duration? staleAfter,
    Duration? deadStreamAfter,
    int? maxRestartAttempts,
  }) : _databaseOverride = database,
       _isLocationServiceEnabled =
           isLocationServiceEnabled ?? Geolocator.isLocationServiceEnabled,
       _checkPermission = checkPermission ?? Geolocator.checkPermission,
       _requestPermission = requestPermission ?? Geolocator.requestPermission,
       _positionStream =
           positionStream ??
           ((settings) => Geolocator.getPositionStream(locationSettings: settings)),
       _currentDriverId = currentDriverId ?? (() => (auth ?? FirebaseAuth.instance).currentUser?.uid),
       _writeLocation =
           writeLocation ??
           ((schoolId, tripId, data) =>
               (database ?? FirebaseDatabase.instance)
                   .ref('schools/$schoolId/trips/$tripId/location')
                   .set(data)),
       _watchdogInterval = watchdogInterval ?? _defaultWatchdogInterval,
       _staleAfter = staleAfter ?? _defaultStaleAfter,
       _deadStreamAfter = deadStreamAfter ?? _defaultDeadStreamAfter,
       _maxRestartAttempts = maxRestartAttempts ?? _defaultMaxRestartAttempts;

  // Stored, not resolved, at construction time — resolving eagerly to
  // FirebaseDatabase.instance would call into a real platform channel even
  // for a repository built entirely from fakes (see the constructor
  // parameters below), which is exactly what broke this file's own unit
  // tests before this field became lazy via the [_database] getter.
  final FirebaseDatabase? _databaseOverride;
  FirebaseDatabase get _database => _databaseOverride ?? FirebaseDatabase.instance;

  // Injected indirections around Geolocator's/Firebase's APIs purely so
  // this repository's failure/recovery behavior (Production hardening: GPS
  // failure handling) is unit-testable with plain fakes — see
  // driver_tracking_repository_test.dart — without a real device, emulator,
  // or platform-channel mock, and without hand-rolling brittle fakes of the
  // firebase_auth/firebase_database SDK classes themselves. Defaults to the
  // real Geolocator/Firebase calls.
  final Future<bool> Function() _isLocationServiceEnabled;
  final Future<LocationPermission> Function() _checkPermission;
  final Future<LocationPermission> Function() _requestPermission;
  final Stream<Position> Function(LocationSettings settings) _positionStream;
  final String? Function() _currentDriverId;
  final Future<void> Function(String schoolId, String tripId, Map<String, dynamic> data)
  _writeLocation;

  // Also overridable (defaulting to the real thresholds documented above
  // each `_default*` constant) purely so tests can exercise the watchdog's
  // real Timer-driven staleness/dead-stream/restart-cap logic in
  // milliseconds instead of genuinely waiting 45 seconds to 2 minutes.
  final Duration _watchdogInterval;
  final Duration _staleAfter;
  final Duration _deadStreamAfter;
  final int _maxRestartAttempts;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _watchdog;
  final _statusController = StreamController<DriverTrackingStatus>.broadcast();

  DriverTrackingStatus _status = DriverTrackingStatus.stopped;
  String? _activeSchoolId;
  String? _activeTripId;
  DateTime? _lastPositionAt;
  int _restartAttempts = 0;
  bool _lastWriteFailed = false;

  /// The tracking repository's current, and every subsequent, status — the
  /// driver app's presentation layer (TripsBloc) subscribes to this once
  /// and folds updates into its own state rather than polling.
  Stream<DriverTrackingStatus> get statusStream => _statusController.stream;
  DriverTrackingStatus get status => _status;

  void _emit(DriverTrackingStatus next) {
    _status = next;
    if (!_statusController.isClosed) _statusController.add(next);
  }

  Future<void> startTracking({
    required String schoolId,
    required String tripId,
  }) async {
    // Already tracking this exact trip with a live subscription — a
    // duplicate call (e.g. TripsBloc re-reconciling on an unrelated
    // snapshot update) is a no-op rather than tearing down and rebuilding
    // a perfectly healthy stream. Resume-after-pause and a genuinely
    // different trip both fall through, since `stopTracking` (called by
    // pause/complete/cancel) always clears `_activeTripId` first.
    if (_positionSubscription != null &&
        _activeTripId == tripId &&
        _activeSchoolId == schoolId) {
      return;
    }

    // database.rules.json only allows writes to this node from the uid
    // recorded as `driverId`, so it must be stamped on every update.
    final driverId = _currentDriverId();
    if (driverId == null) {
      throw StateError('A signed-in driver is required to start tracking.');
    }

    await stopTracking();
    _emit(DriverTrackingStatus.starting);

    final serviceEnabled = await _isLocationServiceEnabled();
    if (!serviceEnabled) {
      _emit(DriverTrackingStatus.locationServiceDisabled);
      throw const LocationServiceDisabledException();
    }

    var permission = await _checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      _emit(DriverTrackingStatus.permissionPermanentlyDenied);
      throw const PermissionDeniedException(
        'Location permission was permanently denied.',
      );
    }
    if (permission == LocationPermission.denied) {
      _emit(DriverTrackingStatus.permissionDenied);
      throw const PermissionDeniedException('Location permission was denied.');
    }

    _activeSchoolId = schoolId;
    _activeTripId = tripId;
    _restartAttempts = 0;
    _lastWriteFailed = false;
    _subscribe(schoolId: schoolId, tripId: tripId, driverId: driverId);
  }

  void _subscribe({
    required String schoolId,
    required String tripId,
    required String driverId,
  }) {
    _lastPositionAt = DateTime.now();
    _startWatchdog(schoolId: schoolId, tripId: tripId, driverId: driverId);

    _positionSubscription = _positionStream(_trackingSettings()).listen(
      (position) async {
        _lastPositionAt = DateTime.now();
        _restartAttempts = 0;
        try {
          await _writeLocation(schoolId, tripId, {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'heading': position.heading,
            'speed': position.speed,
            'accuracy': position.accuracy,
            'driverId': driverId,
            'timestamp': ServerValue.timestamp,
          });
          // Requirement F: never let a UI observer believe a location
          // update landed unless the write actually succeeded — only a
          // successful write ever moves the status to `tracking`/
          // `recovered`, both computed from whether the *previous*
          // attempt had failed.
          _emit(
            _lastWriteFailed
                ? DriverTrackingStatus.recovered
                : DriverTrackingStatus.tracking,
          );
          _lastWriteFailed = false;
        } catch (error) {
          _lastWriteFailed = true;
          _emit(classifyWriteError(error));
          // Best-effort: this single dropped location update isn't fatal —
          // the position stream itself is untouched (Requirement C), so the
          // very next fix retries the write on its own.
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _emit(classifyPositionStreamError(error));
        _attemptRestart(schoolId: schoolId, tripId: tripId, driverId: driverId);
      },
      cancelOnError: false,
    );
  }

  void _startWatchdog({
    required String schoolId,
    required String tripId,
    required String driverId,
  }) {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(_watchdogInterval, (_) {
      final lastPositionAt = _lastPositionAt;
      if (lastPositionAt == null) return;
      final silentFor = DateTime.now().difference(lastPositionAt);

      if (silentFor >= _deadStreamAfter) {
        _attemptRestart(schoolId: schoolId, tripId: tripId, driverId: driverId);
      } else if (silentFor >= _staleAfter && _status != DriverTrackingStatus.staleLocation) {
        _emit(DriverTrackingStatus.staleLocation);
      }
    });
  }

  /// A bounded, non-aggressive recovery attempt (Requirement G): re-checks
  /// permission/service (a revoked permission is reported, not retried —
  /// only the driver granting it again can fix that) and, if location is
  /// still genuinely available, cancels and re-subscribes the stream once.
  /// After [_maxRestartAttempts] failed rounds within one tracking session,
  /// gives up into [DriverTrackingStatus.gpsError] rather than looping
  /// forever — the next explicit [startTracking] call (e.g. the driver
  /// backgrounding and reopening the app, or TripsBloc's own reconciliation
  /// on the next trip snapshot) resets the counter.
  Future<void> _attemptRestart({
    required String schoolId,
    required String tripId,
    required String driverId,
  }) async {
    if (_activeTripId != tripId || _activeSchoolId != schoolId) return;

    final serviceEnabled = await _isLocationServiceEnabled();
    if (!serviceEnabled) {
      _emit(DriverTrackingStatus.locationServiceDisabled);
      await _cancelStreamOnly();
      return;
    }
    final permission = await _checkPermission();
    if (permission == LocationPermission.deniedForever) {
      _emit(DriverTrackingStatus.permissionPermanentlyDenied);
      await _cancelStreamOnly();
      return;
    }
    if (permission == LocationPermission.denied) {
      _emit(DriverTrackingStatus.permissionDenied);
      await _cancelStreamOnly();
      return;
    }

    if (_restartAttempts >= _maxRestartAttempts) {
      _emit(DriverTrackingStatus.gpsError);
      await _cancelStreamOnly();
      return;
    }
    _restartAttempts++;

    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _emit(DriverTrackingStatus.reconnecting);
    _subscribe(schoolId: schoolId, tripId: tripId, driverId: driverId);
  }

  /// Cancels just the position stream/watchdog, leaving [_activeTripId] set
  /// so a future explicit [startTracking] call for the same trip is
  /// recognized as a genuine restart rather than a no-op duplicate, and so
  /// [_reconcileTracking]-style callers can tell tracking is not actually
  /// running even though a trip is still active.
  Future<void> _cancelStreamOnly() async {
    _watchdog?.cancel();
    _watchdog = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// On Android, wraps the same accuracy/distance settings this app already
  /// used in a real foreground service via [AndroidSettings.
  /// foregroundNotificationConfig] — this is what keeps GPS updates flowing
  /// once the app is backgrounded or the screen locks. Without it, Android
  /// treats this like any other backgrounded app and can suspend its
  /// location callbacks; a foreground service (with the persistent
  /// notification Android requires to disclose it) is treated as active
  /// foreground usage instead. `GeolocatorLocationService`, which this
  /// starts, ships inside the `geolocator_android` plugin itself — no new
  /// package was added for this.
  ///
  /// `intervalDuration` is set explicitly to 8s: previously unset, which
  /// geolocator silently defaults to 5s internally — 8s keeps the map
  /// clearly "live" for a bus route while trimming a real cost identified
  /// in the prior system audit (this GPS stream is what triggers the
  /// highest-cost Cloud Function in the system on every update). The
  /// existing 10m `distanceFilter` is unchanged and still applies on top of
  /// this — a position only emits once both conditions are met.
  /// `enableWakeLock` is deliberately turned on (default is off): with the
  /// screen locked, the CPU can otherwise sleep and deliver GPS fixes only
  /// in a batch whenever something else wakes the device, which would
  /// silently reintroduce exactly the gap this fix exists to close. The
  /// cost is scoped to the lifetime of an active trip only — `stopTracking`
  /// cancels the stream (and the underlying service) immediately.
  ///
  /// `ACCESS_BACKGROUND_LOCATION` is deliberately not requested anywhere in
  /// this app — see AndroidManifest.xml for why it isn't needed here.
  ///
  /// Web has no foreground-service concept, so it keeps plain
  /// [LocationSettings] with the same accuracy/distance values as before.
  /// RUNTIME UNVERIFIED — DEVICE REQUIRED: the actual Android foreground-
  /// service behavior (surviving a backgrounded app/locked screen) can only
  /// be observed on a physical device or a working emulator, neither of
  /// which is available in this environment; this session verified the
  /// setting is still passed unchanged and that the web code path (used for
  /// all in-browser verification below) behaves correctly.
  LocationSettings _trackingSettings() {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
    }
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
      intervalDuration: const Duration(seconds: 8),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Jammam School Bus',
        notificationText: 'Trip tracking active — تتبع الرحلة نشط',
        setOngoing: true,
        enableWakeLock: true,
      ),
    );
  }

  Future<void> stopTracking() async {
    _watchdog?.cancel();
    _watchdog = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _activeSchoolId = null;
    _activeTripId = null;
    _lastPositionAt = null;
    _restartAttempts = 0;
    _lastWriteFailed = false;
    _emit(DriverTrackingStatus.stopped);
  }

  Future<void> clearLocation({
    required String schoolId,
    required String tripId,
  }) {
    return _database
        .ref('schools/$schoolId/trips/$tripId/location')
        .remove();
  }

  /// A one-off read of the same RTDB node [startTracking] continuously
  /// writes to (see OpsTrackingRepository/live_ops_tab in the admin app,
  /// which reads this identical node) — not a second, independent GPS
  /// fetch. Used when raising an emergency, so the recorded location is
  /// whatever the trip's live tracking already knows, not a fresh
  /// Geolocator call. Returns null if tracking isn't currently live for
  /// this trip (no fake/zeroed location is ever returned).
  Future<({double latitude, double longitude})?> getLastKnownLocation({
    required String schoolId,
    required String tripId,
  }) async {
    final snapshot = await _database
        .ref('schools/$schoolId/trips/$tripId/location')
        .get();
    final raw = snapshot.value;
    if (raw is! Map) return null;
    final data = Map<Object?, Object?>.from(raw);
    final latitude = (data['latitude'] as num?)?.toDouble();
    final longitude = (data['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return null;
    return (latitude: latitude, longitude: longitude);
  }

  /// Releases resources this repository owns for the app's lifetime (not
  /// per-trip — see [stopTracking] for that). Call once, e.g. from
  /// TripsBloc.close().
  Future<void> dispose() async {
    await stopTracking();
    await _statusController.close();
  }
}

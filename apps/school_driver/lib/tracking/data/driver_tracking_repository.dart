import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:geolocator/geolocator.dart';

class DriverTrackingRepository {
  DriverTrackingRepository({
    FirebaseDatabase? database,
    FirebaseAuth? auth,
  }) : _database = database ?? FirebaseDatabase.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseDatabase _database;
  final FirebaseAuth _auth;

  StreamSubscription<Position>? _positionSubscription;

  Future<void> startTracking({
    required String schoolId,
    required String tripId,
  }) async {
    // database.rules.json only allows writes to this node from the uid
    // recorded as `driverId`, so it must be stamped on every update.
    final driverId = _auth.currentUser?.uid;
    if (driverId == null) {
      throw StateError('A signed-in driver is required to start tracking.');
    }

    final serviceEnabled =
    await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw StateError('Location service is disabled.');
    }

    var permission =
    await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
      await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Location permission was denied.');
    }

    final reference = _database
        .ref('schools/$schoolId/trips/$tripId/location');

    await _positionSubscription?.cancel();

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _trackingSettings(),
    ).listen((position) async {
      try {
        await reference.set({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'heading': position.heading,
          'speed': position.speed,
          'accuracy': position.accuracy,
          'driverId': driverId,
          'timestamp': ServerValue.timestamp,
        });
      } catch (_) {
        // Best-effort: a single dropped location update (a momentary
        // RTDB disconnect, or database.rules.json's authorizedSchools
        // check not having caught up yet for a brand-new membership)
        // isn't worth surfacing to the driver — the next position
        // update retries on its own.
      }
    });
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
    await _positionSubscription?.cancel();
    _positionSubscription = null;
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
}
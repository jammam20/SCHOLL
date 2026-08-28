import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
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

    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((position) async {
          try {
            await reference.set({
              'latitude': position.latitude,
              'longitude': position.longitude,
              'heading': position.heading,
              'speed': position.speed,
              'accuracy': position.accuracy,
              'driverId': driverId,
              'timestamp':
              ServerValue.timestamp,
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
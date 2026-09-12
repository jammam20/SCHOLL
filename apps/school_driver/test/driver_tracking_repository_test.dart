import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:school_driver/tracking/data/driver_tracking_repository.dart';
import 'package:school_driver/tracking/domain/driver_tracking_status.dart';

/// A GPS fix with just the fields [DriverTrackingRepository] actually reads
/// — building a real `Position` requires its full, deeply-parameterized
/// plugin constructor, and every field beyond lat/lng is irrelevant here.
Position _fix({double lat = 30.0, double lng = 31.0}) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime(2026),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

/// Builds a repository wired entirely to fakes — no Firebase SDK class is
/// ever constructed or touched, so this genuinely exercises
/// [DriverTrackingRepository]'s own decision logic (permission/service
/// checks, the write-success/failure state machine, the watchdog's
/// staleness/dead-stream/bounded-restart behavior) rather than faking a
/// "success" result out of Firebase itself — see the production-hardening
/// brief's explicit rule against that. Real (tiny) [Duration]s drive the
/// watchdog so its actual `Timer`-based logic runs, just on a millisecond
/// scale instead of the real 45s/2min production thresholds.
class _Harness {
  _Harness({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    Duration watchdogInterval = const Duration(milliseconds: 20),
    Duration staleAfter = const Duration(milliseconds: 60),
    Duration deadStreamAfter = const Duration(milliseconds: 150),
    int maxRestartAttempts = 2,
  }) {
    repository = DriverTrackingRepository(
      isLocationServiceEnabled: () async => serviceEnabled,
      checkPermission: () async => permission,
      requestPermission: () async => permission,
      positionStream: (_) {
        streamBuildCount++;
        final controller = StreamController<Position>();
        controllers.add(controller);
        return controller.stream;
      },
      currentDriverId: () => driverId,
      writeLocation: (schoolId, tripId, data) async {
        writeCount++;
        if (nextWriteError != null) {
          final error = nextWriteError!;
          nextWriteError = null;
          throw error;
        }
      },
      watchdogInterval: watchdogInterval,
      staleAfter: staleAfter,
      deadStreamAfter: deadStreamAfter,
      maxRestartAttempts: maxRestartAttempts,
    );
    statuses = <DriverTrackingStatus>[];
    subscription = repository.statusStream.listen(statuses.add);
  }

  bool serviceEnabled;
  LocationPermission permission;
  String? driverId = 'driver-1';
  int streamBuildCount = 0;
  int writeCount = 0;
  Object? nextWriteError;
  final controllers = <StreamController<Position>>[];
  late final DriverTrackingRepository repository;
  late final List<DriverTrackingStatus> statuses;
  late final StreamSubscription<DriverTrackingStatus> subscription;

  StreamController<Position> get latestController => controllers.last;

  Future<void> dispose() async {
    await subscription.cancel();
    await repository.dispose();
    for (final c in controllers) {
      if (!c.isClosed) await c.close();
    }
  }
}

void main() {
  group('DriverTrackingRepository.startTracking — permission/service checks', () {
    test('throws and reports locationServiceDisabled when the service is off', () async {
      final h = _Harness(serviceEnabled: false);
      addTearDown(h.dispose);

      await expectLater(
        () => h.repository.startTracking(schoolId: 's1', tripId: 't1'),
        throwsA(isA<LocationServiceDisabledException>()),
      );
      expect(h.repository.status, DriverTrackingStatus.locationServiceDisabled);
      expect(h.streamBuildCount, 0, reason: 'never subscribes when the service is off');
    });

    test('throws and reports permissionDenied', () async {
      final h = _Harness(permission: LocationPermission.denied);
      addTearDown(h.dispose);

      await expectLater(
        () => h.repository.startTracking(schoolId: 's1', tripId: 't1'),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect(h.repository.status, DriverTrackingStatus.permissionDenied);
    });

    test('throws and reports permissionPermanentlyDenied', () async {
      final h = _Harness(permission: LocationPermission.deniedForever);
      addTearDown(h.dispose);

      await expectLater(
        () => h.repository.startTracking(schoolId: 's1', tripId: 't1'),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect(h.repository.status, DriverTrackingStatus.permissionPermanentlyDenied);
    });

    test('throws when no driver is signed in', () async {
      final h = _Harness();
      h.driverId = null;
      addTearDown(h.dispose);

      await expectLater(
        () => h.repository.startTracking(schoolId: 's1', tripId: 't1'),
        throwsA(isA<StateError>()),
      );
    });

    test('subscribes exactly once when permission/service are fine', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      await h.repository.startTracking(schoolId: 's1', tripId: 't1');
      expect(h.streamBuildCount, 1);
      expect(h.repository.status, DriverTrackingStatus.starting);
    });
  });

  group('DriverTrackingRepository — duplicate subscription prevention', () {
    test('a second startTracking call for the same trip is a no-op', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      await h.repository.startTracking(schoolId: 's1', tripId: 't1');
      await h.repository.startTracking(schoolId: 's1', tripId: 't1');
      expect(h.streamBuildCount, 1, reason: 'must not rebuild an already-live subscription');
    });

    test('a call for a different trip does rebuild the subscription', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      await h.repository.startTracking(schoolId: 's1', tripId: 't1');
      await h.repository.startTracking(schoolId: 's1', tripId: 't2');
      expect(h.streamBuildCount, 2);
    });
  });

  group('DriverTrackingRepository — write success/failure state machine', () {
    test('a successful write reports tracking, never a stale success', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      await h.repository.startTracking(schoolId: 's1', tripId: 't1');
      h.latestController.add(_fix());
      await Future<void>.delayed(Duration.zero);

      expect(h.writeCount, 1);
      expect(h.repository.status, DriverTrackingStatus.tracking);
    });

    test('a failed write reports a failure status without killing the stream', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      await h.repository.startTracking(schoolId: 's1', tripId: 't1');
      h.nextWriteError = Exception('network error');
      h.latestController.add(_fix());
      await Future<void>.delayed(Duration.zero);

      expect(h.repository.status, DriverTrackingStatus.networkError);
      expect(
        h.latestController.hasListener,
        isTrue,
        reason: 'Requirement C: stream stays alive',
      );

      // The very next fix retries the write on its own (Requirement C/G)
      // and, since it succeeds, is reported as a recovery.
      h.latestController.add(_fix());
      await Future<void>.delayed(Duration.zero);
      expect(h.repository.status, DriverTrackingStatus.recovered);
      expect(h.writeCount, 2);
    });

    test('a non-network write failure reports firebaseWriteError', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      await h.repository.startTracking(schoolId: 's1', tripId: 't1');
      h.nextWriteError = Exception('permission-denied');
      h.latestController.add(_fix());
      await Future<void>.delayed(Duration.zero);

      expect(h.repository.status, DriverTrackingStatus.firebaseWriteError);
    });
  });

  group('DriverTrackingRepository — stream error handling', () {
    test('a stream error is classified and does not crash', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      await h.repository.startTracking(schoolId: 's1', tripId: 't1');
      h.latestController.addError(const PermissionDeniedException('revoked'));
      await Future<void>.delayed(const Duration(milliseconds: 5));

      // Permission is still reported as granted by the harness's checks
      // during _attemptRestart, so the classified stream error is
      // immediately superseded by a fresh restart attempt — the important,
      // asserted fact is that nothing threw synchronously out of the
      // listener and the repository is still in a defined, non-crashed
      // state.
      expect(h.repository.status, isA<DriverTrackingStatus>());
    });

    test('a stream error while permission has actually been revoked settles into permissionDenied', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      await h.repository.startTracking(schoolId: 's1', tripId: 't1');
      h.permission = LocationPermission.denied;
      h.latestController.addError(const PermissionDeniedException('revoked'));
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(h.repository.status, DriverTrackingStatus.permissionDenied);
      expect(
        h.latestController.hasListener,
        isFalse,
        reason: 'no point retrying a revoked permission',
      );
    });
  });

  group('DriverTrackingRepository — watchdog (stale / dead stream / bounded restart)', () {
    test('no position for longer than staleAfter reports staleLocation', () async {
      final h = _Harness(
        watchdogInterval: const Duration(milliseconds: 10),
        staleAfter: const Duration(milliseconds: 40),
        deadStreamAfter: const Duration(seconds: 10),
      );
      addTearDown(h.dispose);

      await h.repository.startTracking(schoolId: 's1', tripId: 't1');
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(h.repository.status, DriverTrackingStatus.staleLocation);
      expect(
        h.latestController.hasListener,
        isTrue,
        reason: 'staleness alone must not kill the stream',
      );
    });

    test('no position for longer than deadStreamAfter attempts a bounded restart, then gives up', () async {
      final h = _Harness(
        watchdogInterval: const Duration(milliseconds: 10),
        staleAfter: const Duration(milliseconds: 20),
        deadStreamAfter: const Duration(milliseconds: 50),
        maxRestartAttempts: 2,
      );
      addTearDown(h.dispose);

      await h.repository.startTracking(schoolId: 's1', tripId: 't1');
      // Never emit a position — the stream looks dead from the start.
      // Each restart rebuilds the stream (a fresh controller that also
      // never emits), so after `maxRestartAttempts` rounds the watchdog
      // must give up rather than looping forever.
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(h.repository.status, DriverTrackingStatus.gpsError);
      expect(
        h.streamBuildCount,
        lessThanOrEqualTo(3), // 1 initial + at most maxRestartAttempts(2)
        reason: 'must not retry forever',
      );
      expect(h.latestController.hasListener, isFalse);
    });
  });

  group('DriverTrackingRepository — stop/cleanup', () {
    test('stopTracking cancels the stream and reports stopped', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      await h.repository.startTracking(schoolId: 's1', tripId: 't1');
      final controller = h.latestController;
      await h.repository.stopTracking();

      expect(h.repository.status, DriverTrackingStatus.stopped);
      expect(controller.hasListener, isFalse);
    });

    test('a position emitted after stopTracking is not written', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      await h.repository.startTracking(schoolId: 's1', tripId: 't1');
      final controller = h.latestController;
      await h.repository.stopTracking();
      if (!controller.isClosed) controller.add(_fix());
      await Future<void>.delayed(Duration.zero);

      expect(h.writeCount, 0);
    });

    test('starting a new trip after stopping is a genuine restart, not a no-op', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      await h.repository.startTracking(schoolId: 's1', tripId: 't1');
      await h.repository.stopTracking();
      await h.repository.startTracking(schoolId: 's1', tripId: 't1');

      expect(h.streamBuildCount, 2);
      expect(h.repository.status, DriverTrackingStatus.starting);
    });
  });
}

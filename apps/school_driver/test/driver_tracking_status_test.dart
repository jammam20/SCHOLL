import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:school_driver/tracking/domain/driver_tracking_status.dart';

void main() {
  group('classifyPositionStreamError', () {
    test('LocationServiceDisabledException maps to locationServiceDisabled', () {
      expect(
        classifyPositionStreamError(const LocationServiceDisabledException()),
        DriverTrackingStatus.locationServiceDisabled,
      );
    });

    test('PermissionDeniedException maps to permissionDenied', () {
      expect(
        classifyPositionStreamError(const PermissionDeniedException('denied')),
        DriverTrackingStatus.permissionDenied,
      );
    });

    test('any other error maps to gpsError', () {
      expect(classifyPositionStreamError(StateError('boom')), DriverTrackingStatus.gpsError);
      expect(classifyPositionStreamError('a plain string error'), DriverTrackingStatus.gpsError);
    });
  });

  group('classifyWriteError', () {
    for (final marker in [
      'network error',
      'Connection disconnected',
      'operation timed out',
      'request timeout',
      'service unavailable',
      'device is offline',
    ]) {
      test('"$marker" classifies as networkError', () {
        expect(classifyWriteError(Exception(marker)), DriverTrackingStatus.networkError);
      });
    }

    test('a non-connectivity error classifies as firebaseWriteError', () {
      expect(
        classifyWriteError(Exception('permission-denied: Missing permissions')),
        DriverTrackingStatus.firebaseWriteError,
      );
    });

    test('classification is case-insensitive', () {
      expect(classifyWriteError(Exception('NETWORK ERROR')), DriverTrackingStatus.networkError);
    });
  });

  group('DriverTrackingStatusX.isProblem', () {
    test('silent states report false', () {
      for (final status in [
        DriverTrackingStatus.stopped,
        DriverTrackingStatus.starting,
        DriverTrackingStatus.tracking,
        DriverTrackingStatus.recovered,
      ]) {
        expect(status.isProblem, isFalse, reason: 'status: $status');
      }
    });

    test('failure states report true', () {
      for (final status in [
        DriverTrackingStatus.permissionDenied,
        DriverTrackingStatus.permissionPermanentlyDenied,
        DriverTrackingStatus.locationServiceDisabled,
        DriverTrackingStatus.gpsError,
        DriverTrackingStatus.networkError,
        DriverTrackingStatus.firebaseWriteError,
        DriverTrackingStatus.staleLocation,
        DriverTrackingStatus.reconnecting,
      ]) {
        expect(status.isProblem, isTrue, reason: 'status: $status');
      }
    });
  });

  group('DriverTrackingStatusX.streamIsAlive', () {
    test('the stream is considered dead exactly in the states that cancel it', () {
      for (final status in [
        DriverTrackingStatus.stopped,
        DriverTrackingStatus.permissionDenied,
        DriverTrackingStatus.permissionPermanentlyDenied,
        DriverTrackingStatus.locationServiceDisabled,
        DriverTrackingStatus.gpsError,
      ]) {
        expect(status.streamIsAlive, isFalse, reason: 'status: $status');
      }
    });

    test('the stream is considered alive in every recoverable/ongoing state', () {
      for (final status in [
        DriverTrackingStatus.starting,
        DriverTrackingStatus.tracking,
        DriverTrackingStatus.staleLocation,
        DriverTrackingStatus.reconnecting,
        DriverTrackingStatus.networkError,
        DriverTrackingStatus.firebaseWriteError,
        DriverTrackingStatus.recovered,
      ]) {
        expect(status.streamIsAlive, isTrue, reason: 'status: $status');
      }
    });
  });
}

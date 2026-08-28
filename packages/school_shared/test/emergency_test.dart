import 'package:school_shared/school_shared.dart';
import 'package:test/test.dart';

void main() {
  group('EmergencyType.tryParse', () {
    test('parses every valid wire value', () {
      expect(EmergencyTypeX.tryParse('accident'), EmergencyType.accident);
      expect(EmergencyTypeX.tryParse('vehicle_breakdown'), EmergencyType.vehicleBreakdown);
      expect(EmergencyTypeX.tryParse('medical'), EmergencyType.medical);
      expect(EmergencyTypeX.tryParse('security'), EmergencyType.security);
      expect(EmergencyTypeX.tryParse('other'), EmergencyType.other);
    });

    test('rejects an invalid/garbage type', () {
      expect(EmergencyTypeX.tryParse('fire'), isNull);
      expect(EmergencyTypeX.tryParse(''), isNull);
      expect(EmergencyTypeX.tryParse(null), isNull);
      expect(EmergencyTypeX.tryParse(42), isNull);
      // Camel-case must not accidentally parse — the wire format is
      // snake_case only.
      expect(EmergencyTypeX.tryParse('vehicleBreakdown'), isNull);
    });
  });

  group('EmergencyStatus.tryParse', () {
    test('parses valid values', () {
      expect(EmergencyStatusX.tryParse('active'), EmergencyStatus.active);
      expect(EmergencyStatusX.tryParse('resolved'), EmergencyStatus.resolved);
    });

    test('rejects an invalid status', () {
      expect(EmergencyStatusX.tryParse('closed'), isNull);
    });
  });

  group('checkEmergencyCreationEligibility', () {
    test('eligible when the trip is active and location is available', () {
      expect(
        checkEmergencyCreationEligibility(tripStatus: TripStatus.active, hasLocation: true),
        EmergencyCreationEligibility.eligible,
      );
    });

    test('eligible when the trip is paused and location is available', () {
      expect(
        checkEmergencyCreationEligibility(tripStatus: TripStatus.paused, hasLocation: true),
        EmergencyCreationEligibility.eligible,
      );
    });

    test('location unavailable takes priority regardless of trip status', () {
      expect(
        checkEmergencyCreationEligibility(tripStatus: TripStatus.active, hasLocation: false),
        EmergencyCreationEligibility.locationUnavailable,
      );
    });

    test('rejected for every non-active/paused trip status', () {
      for (final status in [
        TripStatus.scheduled,
        TripStatus.starting,
        TripStatus.completed,
        TripStatus.cancelled,
        TripStatus.emergency,
      ]) {
        expect(
          checkEmergencyCreationEligibility(tripStatus: status, hasLocation: true),
          EmergencyCreationEligibility.tripNotActive,
          reason: 'status: $status',
        );
      }
    });
  });

  group('checkEmergencyResolutionEligibility', () {
    test('eligible for an active emergency and an authorized caller', () {
      expect(
        checkEmergencyResolutionEligibility(status: EmergencyStatus.active, isAuthorized: true),
        EmergencyResolutionEligibility.eligible,
      );
    });

    test('an already-resolved emergency is rejected even for an authorized caller', () {
      expect(
        checkEmergencyResolutionEligibility(status: EmergencyStatus.resolved, isAuthorized: true),
        EmergencyResolutionEligibility.alreadyResolved,
      );
    });

    test('an unauthorized caller is rejected for a still-active emergency', () {
      expect(
        checkEmergencyResolutionEligibility(status: EmergencyStatus.active, isAuthorized: false),
        EmergencyResolutionEligibility.unauthorized,
      );
    });

    test('already-resolved is reported even for an unauthorized caller (no info leak either way)', () {
      expect(
        checkEmergencyResolutionEligibility(status: EmergencyStatus.resolved, isAuthorized: false),
        EmergencyResolutionEligibility.alreadyResolved,
      );
    });
  });

  group('SchoolEmergency.fromMap', () {
    test('parses a fully populated map', () {
      final createdAt = DateTime(2026, 1, 1, 8);
      final resolvedAt = DateTime(2026, 1, 1, 8, 30);

      final emergency = SchoolEmergency.fromMap('e1', {
        'schoolId': 'school-1',
        'tripId': 'trip-1',
        'driverId': 'driver-1',
        'busId': 'bus-1',
        'routeId': 'route-1',
        'type': 'vehicle_breakdown',
        'status': 'resolved',
        'latitude': 30.1,
        'longitude': 31.2,
        'createdAt': createdAt,
        'resolvedAt': resolvedAt,
        'resolvedBy': 'admin-1',
        'resolutionNote': 'Tow truck dispatched.',
        'driverNote': 'Engine stalled.',
      });

      expect(emergency.id, 'e1');
      expect(emergency.schoolId, 'school-1');
      expect(emergency.tripId, 'trip-1');
      expect(emergency.driverId, 'driver-1');
      expect(emergency.busId, 'bus-1');
      expect(emergency.routeId, 'route-1');
      expect(emergency.type, EmergencyType.vehicleBreakdown);
      expect(emergency.status, EmergencyStatus.resolved);
      expect(emergency.isActive, isFalse);
      expect(emergency.latitude, 30.1);
      expect(emergency.longitude, 31.2);
      expect(emergency.createdAt, createdAt);
      expect(emergency.resolvedAt, resolvedAt);
      expect(emergency.resolvedBy, 'admin-1');
      expect(emergency.resolutionNote, 'Tow truck dispatched.');
      expect(emergency.driverNote, 'Engine stalled.');
    });

    test('defaults sensibly for a minimal, freshly created active emergency', () {
      final emergency = SchoolEmergency.fromMap('e2', {
        'schoolId': 'school-1',
        'tripId': 'trip-1',
        'driverId': 'driver-1',
        'busId': 'bus-1',
        'type': 'medical',
        'status': 'active',
        'latitude': 30.0,
        'longitude': 31.0,
        'createdAt': DateTime(2026, 1, 1),
      });

      expect(emergency.routeId, isNull);
      expect(emergency.isActive, isTrue);
      expect(emergency.resolvedAt, isNull);
      expect(emergency.resolvedBy, isNull);
      expect(emergency.resolutionNote, isNull);
      expect(emergency.driverNote, isNull);
    });
  });
}

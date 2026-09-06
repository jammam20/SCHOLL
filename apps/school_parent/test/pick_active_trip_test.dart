import 'package:flutter_test/flutter_test.dart';
import 'package:school_parent/features/trips/domain/pick_active_trip.dart';
import 'package:school_shared/school_shared.dart';

SchoolTrip _trip({
  required String id,
  required TripStatus status,
  required DateTime scheduledAt,
}) {
  return SchoolTrip(
    id: id,
    schoolId: 'school-1',
    routeId: 'route-1',
    busId: 'bus-1',
    driverId: 'driver-1',
    status: status,
    scheduledAt: scheduledAt,
  );
}

void main() {
  group('pickActiveTrip', () {
    test('returns null for no candidates', () {
      expect(pickActiveTrip(const []), isNull);
    });

    // Regression test: a real bug found during live QA — a driver's return
    // trip (scheduled earlier, currently `active`) was invisible to the
    // parent app because an unrelated later-scheduled trip on the same
    // route had been cancelled. watchLatestTripForRoute orders candidates
    // newest-scheduled-first with no idea which one is actually live, so a
    // cancelled trip scheduled *after* the active one always sorted first
    // and permanently hid it.
    test(
      'a live trip wins over a later-scheduled cancelled trip',
      () {
        final cancelledLater = _trip(
          id: 'later',
          status: TripStatus.cancelled,
          scheduledAt: DateTime(2026, 9, 3, 20, 35),
        );
        final activeEarlier = _trip(
          id: 'earlier',
          status: TripStatus.active,
          scheduledAt: DateTime(2026, 9, 3, 20, 25),
        );
        // Newest-scheduled-first, matching watchLatestTripForRoute's order.
        final candidates = [cancelledLater, activeEarlier];

        expect(pickActiveTrip(candidates)?.id, 'earlier');
      },
    );

    for (final status in [
      TripStatus.starting,
      TripStatus.active,
      TripStatus.paused,
      TripStatus.emergency,
    ]) {
      test('a $status trip counts as live and wins', () {
        final live = _trip(
          id: 'live',
          status: status,
          scheduledAt: DateTime(2026, 9, 3, 8),
        );
        final cancelledNewer = _trip(
          id: 'newer',
          status: TripStatus.cancelled,
          scheduledAt: DateTime(2026, 9, 3, 9),
        );
        expect(pickActiveTrip([cancelledNewer, live])?.id, 'live');
      });
    }

    test(
      'with no live trip, the newest non-cancelled candidate wins',
      () {
        final cancelledNewest = _trip(
          id: 'cancelled',
          status: TripStatus.cancelled,
          scheduledAt: DateTime(2026, 9, 3, 9),
        );
        final scheduledOlder = _trip(
          id: 'scheduled',
          status: TripStatus.scheduled,
          scheduledAt: DateTime(2026, 9, 3, 8),
        );
        expect(
          pickActiveTrip([cancelledNewest, scheduledOlder])?.id,
          'scheduled',
        );
      },
    );

    test(
      'falls back to the newest candidate when every one is cancelled',
      () {
        final newest = _trip(
          id: 'newest',
          status: TripStatus.cancelled,
          scheduledAt: DateTime(2026, 9, 3, 9),
        );
        final older = _trip(
          id: 'older',
          status: TripStatus.cancelled,
          scheduledAt: DateTime(2026, 9, 3, 8),
        );
        expect(pickActiveTrip([newest, older])?.id, 'newest');
      },
    );
  });
}

import 'package:school_shared/school_shared.dart';

import '../../trips/data/stop_order_repository.dart';
import 'live_bus_position.dart';

/// The parent app's adapter onto the shared [computeTripEta] engine.
///
/// The engine wants a `List<TripStopPoint>` — every remaining stop, with
/// coordinates. A parent can't supply that in full, and deliberately so:
/// firestore.rules only lets a parent read a student document their own uid
/// appears in (`students/{studentId}`), so the pickup coordinates of the
/// *other* children on the same bus are unreadable here — as they should
/// be, since those are other families' home addresses. What a parent *can*
/// read is the trip document itself, which carries the full `stopOrder`,
/// `boardedStudents` and `droppedOffStudents`.
///
/// So this builds the stop list from the two points a parent is entitled to
/// see — their own child's pickup point and the school — kept in their real
/// relative order within `stopOrder`, and reports the child's true position
/// in the full order separately ([stopNumber] of [totalStops]) rather than
/// pretending the engine saw every stop. That keeps every number honest:
/// the ETA is a straight-line estimate to the child's own stop (exactly
/// what the map showed before, now with the engine's stale-GPS/absurd-ETA
/// guards and its explicit "why not" reason), while "stop 3 of 8" comes
/// from the real order.
///
/// Distances are great-circle, not road distances — see [computeTripEta]'s
/// own note on why this project has no road-routing dependency.
class ParentTripEta {
  const ParentTripEta({
    required this.eta,
    required this.stopNumber,
    required this.totalStops,
  });

  /// The shared engine's result over the stops this parent can see.
  final TripEta eta;

  /// This child's 1-based position in the trip's full stop order, or null
  /// when the order hasn't been computed yet for the day, or when this
  /// child isn't on it (e.g. marked absent, so the driver's order skips
  /// their stop).
  final int? stopNumber;

  /// How many stops the full order holds, including the school's own final
  /// stop. Zero before the driver computes the order.
  final int totalStops;

  /// True when we can honestly say "stop N of M".
  bool get hasStopPosition => stopNumber != null && totalStops > 0;
}

/// Builds [ParentTripEta] for one child on one trip.
///
/// [busPosition] is null until the driver starts broadcasting; the engine
/// turns that into [EtaUnavailableReason.noGpsSignal] rather than silently
/// hiding the ETA.
ParentTripEta computeParentTripEta({
  required TripStatus tripStatus,
  required TripStopProgress progress,
  required Student student,
  School? school,
  LiveBusPosition? busPosition,
  DateTime? now,
  TripDirection direction = TripDirection.outbound,
}) {
  final studentReached = progress.isCompletedStop(student.id);
  // The school is this trip's fixed *destination* for an outbound trip —
  // reached only once the trip itself is over — but its fixed *origin* for
  // a return trip (see StopOrderRepository.computeInitialOrder in the
  // driver app, which puts the school first in stopOrder for a return
  // leg): the bus has already left it the moment the trip is actually
  // underway, well before it's `completed`. Getting this wrong would leave
  // the school showing as an upcoming stop for an entire return trip.
  final schoolReached = direction == TripDirection.returnTrip
      ? tripStatus != TripStatus.scheduled && tripStatus != TripStatus.starting
      : tripStatus == TripStatus.completed;

  TripStopPoint? studentStop() => student.hasLocation
      ? TripStopPoint(
          stopId: student.id,
          latitude: student.latitude!,
          longitude: student.longitude!,
          isCompleted: studentReached,
        )
      : null;

  TripStopPoint? schoolStop() => school != null && school.hasLocation
      ? TripStopPoint(
          stopId: schoolStopId,
          latitude: school.latitude!,
          longitude: school.longitude!,
          isCompleted: schoolReached,
          isSchool: true,
        )
      : null;

  final visibleStops = <TripStopPoint>[];
  if (progress.stopOrder.isEmpty) {
    // No order computed for the day yet. The two facts we still know for
    // certain are that this bus is going to this child's pickup point and
    // then to the school, in that order — that's the trip's definition,
    // not a guess about the stops in between.
    final pickup = studentStop();
    final destination = schoolStop();
    if (pickup != null) visibleStops.add(pickup);
    if (destination != null) visibleStops.add(destination);
  } else {
    for (final stopId in progress.stopOrder) {
      if (stopId == student.id) {
        final pickup = studentStop();
        if (pickup != null) visibleStops.add(pickup);
      } else if (stopId == schoolStopId) {
        final destination = schoolStop();
        if (destination != null) visibleStops.add(destination);
      }
      // Every other id is another family's child — unreadable here by
      // design, so it contributes no point to the list.
    }
  }

  final indexInOrder = progress.stopOrder.indexOf(student.id);

  return ParentTripEta(
    eta: computeTripEta(
      tripStatus: tripStatus,
      stopOrder: visibleStops,
      busLatitude: busPosition?.latitude,
      busLongitude: busPosition?.longitude,
      busSpeedMetersPerSecond: busPosition?.speedMetersPerSecond,
      busPositionUpdatedAt: busPosition?.updatedAt,
      now: now,
    ),
    stopNumber: indexInOrder >= 0 ? indexInOrder + 1 : null,
    totalStops: progress.stopOrder.length,
  );
}

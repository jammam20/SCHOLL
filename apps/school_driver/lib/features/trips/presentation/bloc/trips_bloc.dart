import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:school_shared/school_shared.dart';

import '../../../../app/analytics.dart';
import '../../../../tracking/data/driver_tracking_repository.dart';
import '../../../audit/data/audit_log_repository.dart';
import '../../../emergencies/data/emergencies_repository.dart';
import '../../data/stop_order_repository.dart';
import '../../data/trips_repository.dart';
import '../../domain/trip_operation_exception.dart';

abstract class TripsEvent {}

class TripsStarted extends TripsEvent {
  TripsStarted({required this.schoolId, required this.driverId});
  final String schoolId;
  final String driverId;
}

/// scheduled -> starting -> (location tracking starts) -> active
class TripStartRequested extends TripsEvent {
  TripStartRequested({
    required this.schoolId,
    required this.tripId,
    required this.routeId,
    required this.alreadyStarting,
  });
  final String schoolId;
  final String tripId;
  // Needed to look up which students are on this trip's route, so an
  // initial nearest-neighbor pickup order can be computed when it starts.
  final String routeId;
  // True when the trip is already in the transient 'starting' status (e.g.
  // a previous attempt updated the status but failed to start tracking) —
  // skip re-requesting that transition and go straight to tracking + active.
  final bool alreadyStarting;
}

class TripStopOrderChanged extends TripsEvent {
  TripStopOrderChanged({
    required this.schoolId,
    required this.tripId,
    required this.order,
  });
  final String schoolId;
  final String tripId;
  final List<String> order;
}

class TripStudentBoarded extends TripsEvent {
  TripStudentBoarded({
    required this.schoolId,
    required this.tripId,
    required this.studentId,
  });
  final String schoolId;
  final String tripId;
  final String studentId;
}

class TripStudentDroppedOff extends TripsEvent {
  TripStudentDroppedOff({
    required this.schoolId,
    required this.tripId,
    required this.studentId,
  });
  final String schoolId;
  final String tripId;
  final String studentId;
}

class TripPauseRequested extends TripsEvent {
  TripPauseRequested({required this.schoolId, required this.tripId});
  final String schoolId;
  final String tripId;
}

class TripResumeRequested extends TripsEvent {
  TripResumeRequested({required this.schoolId, required this.tripId});
  final String schoolId;
  final String tripId;
}

class TripCompleteRequested extends TripsEvent {
  TripCompleteRequested({required this.schoolId, required this.tripId});
  final String schoolId;
  final String tripId;
}

class TripEmergencyRequested extends TripsEvent {
  TripEmergencyRequested({
    required this.schoolId,
    required this.tripId,
    required this.emergencyType,
    this.driverNote,
  });
  final String schoolId;
  final String tripId;
  final EmergencyType emergencyType;
  final String? driverNote;
}

class TripEmergencyResolveRequested extends TripsEvent {
  TripEmergencyResolveRequested({
    required this.schoolId,
    required this.tripId,
    required this.emergencyId,
    this.resolutionNote,
  });
  final String schoolId;
  final String tripId;
  final String emergencyId;
  final String? resolutionNote;
}

class TripCancelRequested extends TripsEvent {
  TripCancelRequested({required this.schoolId, required this.tripId, this.reason});
  final String schoolId;
  final String tripId;
  // Optional — no UI currently collects this, but the trip document and
  // event log both support it (see SchoolTrip.cancelReason) for whenever
  // a later phase adds a "why are you cancelling" prompt.
  final String? reason;
}

class _TripsSnapshotReceived extends TripsEvent {
  _TripsSnapshotReceived(this.snapshot);
  final QuerySnapshot<Map<String, dynamic>> snapshot;
}

class _TripsSnapshotFailed extends TripsEvent {
  _TripsSnapshotFailed(this.message);
  final String message;
}

abstract class TripsState {
  const TripsState();
}

class TripsInitial extends TripsState {}

class TripsLoading extends TripsState {}

class TripsLoaded extends TripsState {
  TripsLoaded(this.snapshot, {this.actionError});
  final QuerySnapshot<Map<String, dynamic>> snapshot;
  final String? actionError;
}

class TripsFailure extends TripsState {
  TripsFailure(this.message);
  final String message;
}

class TripsBloc extends Bloc<TripsEvent, TripsState> {
  TripsBloc(
    this._repository,
    this._tracking, [
    StopOrderRepository? stopOrder,
    EmergenciesRepository? emergencies,
    AuditLogRepository? auditLog,
  ]) : _stopOrder = stopOrder ?? StopOrderRepository(),
       _emergencies = emergencies ?? EmergenciesRepository(tracking: _tracking),
       _auditLog = auditLog ?? AuditLogRepository(),
       super(TripsInitial()) {
    on<TripsStarted>(_onStarted);
    on<_TripsSnapshotReceived>(_onSnapshot);
    on<_TripsSnapshotFailed>(_onFailure);
    on<TripStartRequested>(_onStartRequested);
    on<TripStopOrderChanged>(_onStopOrderChanged);
    on<TripStudentBoarded>(_onStudentBoarded);
    on<TripStudentDroppedOff>(_onStudentDroppedOff);
    on<TripPauseRequested>(_onPauseRequested);
    on<TripResumeRequested>(_onResumeRequested);
    on<TripCompleteRequested>(_onCompleteRequested);
    on<TripEmergencyRequested>(_onEmergencyRequested);
    on<TripEmergencyResolveRequested>(_onEmergencyResolveRequested);
    on<TripCancelRequested>(_onCancelRequested);
  }

  final TripsRepository _repository;
  final DriverTrackingRepository _tracking;
  final StopOrderRepository _stopOrder;
  final EmergenciesRepository _emergencies;
  final AuditLogRepository _auditLog;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  /// The trip id [_reconcileTracking] last started tracking for, so a
  /// still-active trip's GPS stream isn't torn down and rebuilt on every
  /// unrelated snapshot update (e.g. a boarding change). `null` means
  /// nothing should currently be tracked.
  String? _trackedTripId;

  Future<void> _onStarted(TripsStarted event, Emitter<TripsState> emit) async {
    emit(TripsLoading());

    await _subscription?.cancel();

    _subscription = _repository
        .watchMyTrips(schoolId: event.schoolId, driverId: event.driverId)
        .listen(
          (snapshot) => add(_TripsSnapshotReceived(snapshot)),
          onError: (Object error) =>
              add(_TripsSnapshotFailed(error.toString())),
        );
  }

  void _onSnapshot(_TripsSnapshotReceived event, Emitter<TripsState> emit) {
    emit(TripsLoaded(event.snapshot));
    _reconcileTracking(event.snapshot);
  }

  /// Makes the GPS stream match what the trip list actually says is
  /// happening, not just what the last button tap said. Without this, a
  /// driver's app process being recreated (Android killing and restoring
  /// it, or simply relaunching the app) mid-trip would redraw an
  /// `active`/`emergency` trip's UI correctly from Firestore but never
  /// restart the location stream that only ever starts in response to an
  /// explicit start/resume/emergency button press — silently leaving the
  /// trip looking tracked when it isn't. Also stops tracking if the
  /// tracked trip is no longer `active`/`emergency` (paused, completed, or
  /// cancelled by another client, e.g. an admin).
  ///
  /// Safe to call on every snapshot: only calls startTracking/stopTracking
  /// when which trip needs tracking has actually changed, and
  /// DriverTrackingRepository.startTracking already cancels any existing
  /// stream before starting a new one regardless.
  void _reconcileTracking(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final trips = snapshot.docs
        .map((doc) => SchoolTrip.fromMap(doc.id, doc.data()))
        .toList();
    final needsTracking = tripNeedingTracking(trips);

    if (needsTracking == null) {
      if (_trackedTripId != null) {
        _trackedTripId = null;
        unawaited(_tracking.stopTracking());
      }
      return;
    }

    if (_trackedTripId == needsTracking.id) return;
    _trackedTripId = needsTracking.id;
    unawaited(
      _tracking.startTracking(
        schoolId: needsTracking.schoolId,
        tripId: needsTracking.id,
      ),
    );
  }

  void _onFailure(_TripsSnapshotFailed event, Emitter<TripsState> emit) {
    emit(TripsFailure(event.message));
  }

  /// Finds [tripId] within the bloc's own last-known snapshot — this list
  /// only ever contains trips already scoped to the signed-in driver (see
  /// TripsRepository.watchMyTrips), so a trip found here is guaranteed to
  /// be theirs before a single network call is made for it.
  SchoolTrip? _tripById(String tripId) {
    final current = state;
    if (current is! TripsLoaded) return null;
    for (final doc in current.snapshot.docs) {
      if (doc.id == tripId) return SchoolTrip.fromMap(doc.id, doc.data());
    }
    return null;
  }

  Future<void> _runAction(
    Emitter<TripsState> emit,
    Future<void> Function() action,
  ) async {
    final current = state;
    final snapshot = current is TripsLoaded ? current.snapshot : null;
    if (snapshot == null) return;

    try {
      await action();
    } on TripOperationException catch (e) {
      emit(TripsLoaded(snapshot, actionError: e.message));
    } catch (e) {
      emit(TripsLoaded(snapshot, actionError: e.toString()));
    }
  }

  /// A fast, no-network rejection for a transition that's obviously
  /// invalid from what the bloc already has cached locally (e.g. tapping
  /// "Pause" a second time before the first pause's snapshot update has
  /// come back) — TripsRepository.updateStatus re-validates this again
  /// server-side inside a transaction regardless, so this is purely to
  /// avoid a pointless round trip and surface the same message instantly.
  bool _canTransitionLocally(String tripId, TripStatus next) {
    final trip = _tripById(tripId);
    return trip != null && trip.status.canTransitionTo(next);
  }

  Future<void> _onStartRequested(
    TripStartRequested event,
    Emitter<TripsState> emit,
  ) => _runAction(emit, () async {
    if (!event.alreadyStarting) {
      if (!_canTransitionLocally(event.tripId, TripStatus.starting)) return;
      await _repository.updateStatus(
        schoolId: event.schoolId,
        tripId: event.tripId,
        status: TripStatus.starting,
      );
    }
    await _tracking.startTracking(
      schoolId: event.schoolId,
      tripId: event.tripId,
    );
    await _repository.updateStatus(
      schoolId: event.schoolId,
      tripId: event.tripId,
      status: TripStatus.active,
      extra: {'startedAt': FieldValue.serverTimestamp()},
    );
    // Best-effort: a fresh nearest-neighbor pickup order for today's run.
    // Doesn't block starting the trip if it fails (no GPS fix yet, etc.) —
    // the driver can still set an order by hand from the trip screen.
    unawaited(
      _stopOrder.computeInitialOrder(
        schoolId: event.schoolId,
        tripId: event.tripId,
        routeId: event.routeId,
        direction: _tripById(event.tripId)?.direction ?? TripDirection.outbound,
      ),
    );
    AppAnalytics.logTripStarted(tripId: event.tripId);
  });

  Future<void> _onStopOrderChanged(
    TripStopOrderChanged event,
    Emitter<TripsState> emit,
  ) => _runAction(emit, () async {
    await _stopOrder.setStopOrder(
      schoolId: event.schoolId,
      tripId: event.tripId,
      order: event.order,
    );
  });

  Future<void> _onStudentBoarded(
    TripStudentBoarded event,
    Emitter<TripsState> emit,
  ) => _runAction(emit, () async {
    await _stopOrder.markBoarded(
      schoolId: event.schoolId,
      tripId: event.tripId,
      studentId: event.studentId,
    );
    AppAnalytics.logStudentBoarded(tripId: event.tripId);
  });

  Future<void> _onStudentDroppedOff(
    TripStudentDroppedOff event,
    Emitter<TripsState> emit,
  ) => _runAction(emit, () async {
    await _stopOrder.markDroppedOff(
      schoolId: event.schoolId,
      tripId: event.tripId,
      studentId: event.studentId,
    );
    AppAnalytics.logStudentDroppedOff(tripId: event.tripId);
  });

  Future<void> _onPauseRequested(
    TripPauseRequested event,
    Emitter<TripsState> emit,
  ) => _runAction(emit, () async {
    if (!_canTransitionLocally(event.tripId, TripStatus.paused)) return;
    await _repository.updateStatus(
      schoolId: event.schoolId,
      tripId: event.tripId,
      status: TripStatus.paused,
      extra: {'pausedAt': FieldValue.serverTimestamp()},
    );
    await _tracking.stopTracking();
  });

  Future<void> _onResumeRequested(
    TripResumeRequested event,
    Emitter<TripsState> emit,
  ) => _runAction(emit, () async {
    if (!_canTransitionLocally(event.tripId, TripStatus.active)) return;
    await _repository.updateStatus(
      schoolId: event.schoolId,
      tripId: event.tripId,
      status: TripStatus.active,
      extra: {'resumedAt': FieldValue.serverTimestamp()},
    );
    await _tracking.startTracking(
      schoolId: event.schoolId,
      tripId: event.tripId,
    );
  });

  Future<void> _onCompleteRequested(
    TripCompleteRequested event,
    Emitter<TripsState> emit,
  ) => _runAction(emit, () async {
    if (!_canTransitionLocally(event.tripId, TripStatus.completed)) return;
    await _repository.updateStatus(
      schoolId: event.schoolId,
      tripId: event.tripId,
      status: TripStatus.completed,
      extra: {'completedAt': FieldValue.serverTimestamp()},
    );
    await _tracking.stopTracking();
    await _tracking.clearLocation(
      schoolId: event.schoolId,
      tripId: event.tripId,
    );
    AppAnalytics.logTripCompleted(tripId: event.tripId);
  });

  Future<void> _onEmergencyRequested(
    TripEmergencyRequested event,
    Emitter<TripsState> emit,
  ) => _runAction(emit, () async {
    if (!_canTransitionLocally(event.tripId, TripStatus.emergency)) return;
    // Creates the emergency record and flips the trip's status to
    // TripStatus.emergency together, atomically — see
    // EmergenciesRepository.createEmergency. Both driver-facing paths (the
    // type+notes dialog and the one-tap hold-to-send SOS) land here, so
    // there is exactly one place an emergency is ever raised from.
    final emergencyId = await _emergencies.createEmergency(
      schoolId: event.schoolId,
      tripId: event.tripId,
      type: event.emergencyType,
      driverNote: event.driverNote,
    );
    // The emergency document above is the authoritative record; this is its
    // entry in the school-wide audit trail. Its failure is deliberately
    // swallowed: an SOS that was genuinely raised must never be reported
    // back to the driver as having failed because a secondary, immutable
    // copy of it didn't write. Unlike the batched audit writes in the
    // inspection/incident/verification repositories, this one can't be made
    // atomic with the thing it records — createEmergency already runs in
    // its own transaction.
    try {
      await _auditLog.record(
        schoolId: event.schoolId,
        action: AuditActions.emergencyRaised,
        entityType: 'emergency',
        entityId: emergencyId,
        tripId: event.tripId,
        metadata: {'type': event.emergencyType.value},
      );
    } catch (_) {
      // Intentionally ignored — see above.
    }
    // Make sure tracking is live during an emergency even if the trip was
    // paused (and therefore not currently broadcasting) beforehand.
    await _tracking.startTracking(
      schoolId: event.schoolId,
      tripId: event.tripId,
    );
    AppAnalytics.logEmergencyCreated(
      tripId: event.tripId,
      emergencyType: event.emergencyType.value,
    );
  });

  Future<void> _onEmergencyResolveRequested(
    TripEmergencyResolveRequested event,
    Emitter<TripsState> emit,
  ) => _runAction(emit, () async {
    await _emergencies.resolveEmergency(
      schoolId: event.schoolId,
      tripId: event.tripId,
      emergencyId: event.emergencyId,
      resolutionNote: event.resolutionNote,
    );
    AppAnalytics.logEmergencyResolved(tripId: event.tripId);
  });

  Future<void> _onCancelRequested(
    TripCancelRequested event,
    Emitter<TripsState> emit,
  ) => _runAction(emit, () async {
    if (!_canTransitionLocally(event.tripId, TripStatus.cancelled)) return;
    await _repository.updateStatus(
      schoolId: event.schoolId,
      tripId: event.tripId,
      status: TripStatus.cancelled,
      extra: {
        'cancelledAt': FieldValue.serverTimestamp(),
        if (event.reason != null) 'cancelReason': event.reason,
      },
    );
    await _tracking.stopTracking();
    await _tracking.clearLocation(
      schoolId: event.schoolId,
      tripId: event.tripId,
    );
  });

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    _trackedTripId = null;
    await _tracking.stopTracking();
    return super.close();
  }
}

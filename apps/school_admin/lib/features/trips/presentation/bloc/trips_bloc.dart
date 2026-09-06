import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

import '../../data/trips_repository.dart';

abstract class TripsEvent {}

class TripsStarted extends TripsEvent {
  TripsStarted(this.schoolId);
  final String schoolId;
}

/// Re-subscribes with a bigger page size — see TripsBloc.pageSize.
class TripsLoadMoreRequested extends TripsEvent {}

class TripCreated extends TripsEvent {
  TripCreated({
    required this.schoolId,
    required this.routeId,
    required this.routeName,
    required this.busId,
    required this.busName,
    required this.busPlateNumber,
    required this.driverId,
    required this.driverName,
    required this.scheduledAt,
    this.direction = TripDirection.outbound,
  });

  final String schoolId;
  final String routeId;
  final String routeName;
  final String busId;
  final String busName;
  final String busPlateNumber;
  final String driverId;
  final String driverName;
  final DateTime scheduledAt;
  final TripDirection direction;
}

class TripCancelled extends TripsEvent {
  TripCancelled({required this.schoolId, required this.tripId});
  final String schoolId;
  final String tripId;
}

/// A last-minute bus and/or driver change — see
/// [TripsRepository.reassignTrip], which writes the trip fields, a
/// ReassignmentRecord and an audit entry together.
class TripReassigned extends TripsEvent {
  TripReassigned({
    required this.schoolId,
    required this.tripId,
    this.busId,
    this.busName,
    this.busPlateNumber,
    this.driverId,
    this.driverName,
    this.reason,
  });

  final String schoolId;
  final String tripId;
  final String? busId;
  final String? busName;
  final String? busPlateNumber;
  final String? driverId;
  final String? driverName;
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

abstract class TripsState {}

class TripsInitial extends TripsState {}

class TripsLoading extends TripsState {}

class TripsLoaded extends TripsState {
  TripsLoaded(this.snapshot, {required this.hasMore});
  final QuerySnapshot<Map<String, dynamic>> snapshot;
  final bool hasMore;
}

class TripsFailure extends TripsState {
  TripsFailure(this.message);
  final String message;
}

/// A reassignment that failed *after* the list had loaded, carried
/// alongside the last good snapshot so a failed action shows as a snackbar
/// without blanking the trips list an admin is working in.
class TripsActionFailure extends TripsState {
  TripsActionFailure(this.message, this.snapshot, {required this.hasMore});
  final String message;
  final QuerySnapshot<Map<String, dynamic>>? snapshot;
  final bool hasMore;
}

/// A reassignment that succeeded — emitted once so the page can confirm it
/// without claiming success before the write landed.
class TripsActionSucceeded extends TripsState {
  TripsActionSucceeded(this.snapshot, {required this.hasMore});
  final QuerySnapshot<Map<String, dynamic>>? snapshot;
  final bool hasMore;
}

class TripsBloc extends Bloc<TripsEvent, TripsState> {
  TripsBloc(this._repository) : super(TripsInitial()) {
    on<TripsStarted>(_onStarted);
    on<TripsLoadMoreRequested>(_onLoadMoreRequested);
    on<_TripsSnapshotReceived>(_onSnapshot);
    on<_TripsSnapshotFailed>(_onFailure);
    on<TripCreated>(_onCreated);
    on<TripCancelled>(_onCancelled);
    on<TripReassigned>(_onReassigned);
  }

  static const pageSize = 30;

  final TripsRepository _repository;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  String _schoolId = '';
  int _limit = pageSize;
  QuerySnapshot<Map<String, dynamic>>? _lastSnapshot;

  bool get _hasMore => (_lastSnapshot?.docs.length ?? 0) >= _limit;

  Future<void> _onStarted(TripsStarted event, Emitter<TripsState> emit) async {
    emit(TripsLoading());
    _schoolId = event.schoolId;
    _limit = pageSize;
    await _subscribe();
  }

  Future<void> _onLoadMoreRequested(
    TripsLoadMoreRequested event,
    Emitter<TripsState> emit,
  ) async {
    _limit += pageSize;
    await _subscribe();
  }

  Future<void> _subscribe() async {
    await _subscription?.cancel();
    _subscription = _repository
        .watchTrips(_schoolId, limit: _limit)
        .listen(
          (snapshot) => add(_TripsSnapshotReceived(snapshot)),
          onError: (Object error) =>
              add(_TripsSnapshotFailed(error.toString())),
        );
  }

  void _onSnapshot(_TripsSnapshotReceived event, Emitter<TripsState> emit) {
    _lastSnapshot = event.snapshot;
    emit(
      TripsLoaded(event.snapshot, hasMore: event.snapshot.docs.length >= _limit),
    );
  }

  void _onFailure(_TripsSnapshotFailed event, Emitter<TripsState> emit) {
    emit(TripsFailure(event.message));
  }

  Future<void> _onCreated(TripCreated event, Emitter<TripsState> emit) async {
    try {
      await _repository.createTrip(
        schoolId: event.schoolId,
        routeId: event.routeId,
        routeName: event.routeName,
        busId: event.busId,
        busName: event.busName,
        busPlateNumber: event.busPlateNumber,
        driverId: event.driverId,
        driverName: event.driverName,
        scheduledAt: event.scheduledAt,
        direction: event.direction,
      );
      // No success state to emit here (unlike reassign): the trip list's
      // own Firestore subscription already picks up the new document via
      // _onSnapshot, and TripsActionSucceeded's listener is worded
      // specifically for a reassignment notifying its new driver — reusing
      // it here would show that message for an unrelated action.
    } catch (e) {
      // TripsFailure replaces the whole list with a full-page error view —
      // right for the initial load stream failing, wrong here: a rejected
      // create (e.g. DuplicateActiveTripException, a routine and expected
      // outcome once the bus/driver conflict check landed) is just as
      // recoverable as a failed reassign, and shouldn't blank a trips list
      // the admin is actively working in.
      emit(TripsActionFailure(e.toString(), _lastSnapshot, hasMore: _hasMore));
    }
  }

  Future<void> _onCancelled(
    TripCancelled event,
    Emitter<TripsState> emit,
  ) async {
    try {
      await _repository.updateStatus(
        schoolId: event.schoolId,
        tripId: event.tripId,
        status: 'cancelled',
      );
    } catch (e) {
      emit(TripsFailure(e.toString()));
    }
  }

  Future<void> _onReassigned(
    TripReassigned event,
    Emitter<TripsState> emit,
  ) async {
    try {
      await _repository.reassignTrip(
        schoolId: event.schoolId,
        tripId: event.tripId,
        busId: event.busId,
        busName: event.busName,
        busPlateNumber: event.busPlateNumber,
        driverId: event.driverId,
        driverName: event.driverName,
        reason: event.reason,
      );
      emit(TripsActionSucceeded(_lastSnapshot, hasMore: _hasMore));
    } catch (e) {
      emit(TripsActionFailure(e.toString(), _lastSnapshot, hasMore: _hasMore));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

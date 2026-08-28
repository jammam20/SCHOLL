import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
}

class TripCancelled extends TripsEvent {
  TripCancelled({required this.schoolId, required this.tripId});
  final String schoolId;
  final String tripId;
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

class TripsBloc extends Bloc<TripsEvent, TripsState> {
  TripsBloc(this._repository) : super(TripsInitial()) {
    on<TripsStarted>(_onStarted);
    on<TripsLoadMoreRequested>(_onLoadMoreRequested);
    on<_TripsSnapshotReceived>(_onSnapshot);
    on<_TripsSnapshotFailed>(_onFailure);
    on<TripCreated>(_onCreated);
    on<TripCancelled>(_onCancelled);
  }

  static const pageSize = 30;

  final TripsRepository _repository;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  String _schoolId = '';
  int _limit = pageSize;

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
      );
    } catch (e) {
      emit(TripsFailure(e.toString()));
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

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

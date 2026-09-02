import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/drivers_repository.dart';

abstract class DriversEvent {}

class DriversStarted extends DriversEvent {
  DriversStarted(this.schoolId);
  final String schoolId;
}

/// Re-subscribes with a bigger page size — see DriversBloc.pageSize.
class DriversLoadMoreRequested extends DriversEvent {}

class DriverApproved extends DriversEvent {
  DriverApproved(this.schoolId, this.uid);
  final String schoolId;
  final String uid;
}

class DriverSuspended extends DriversEvent {
  DriverSuspended(this.schoolId, this.uid, {this.reason});
  final String schoolId;
  final String uid;
  final String? reason;
}

class DriverRejected extends DriversEvent {
  DriverRejected(this.schoolId, this.uid, {this.reason});
  final String schoolId;
  final String uid;
  final String? reason;
}

class _DriversSnapshotReceived extends DriversEvent {
  _DriversSnapshotReceived(this.snapshot);
  final QuerySnapshot<Map<String, dynamic>> snapshot;
}

class _DriversSnapshotFailed extends DriversEvent {
  _DriversSnapshotFailed(this.message);
  final String message;
}

abstract class DriversState {}

class DriversInitial extends DriversState {}

class DriversLoading extends DriversState {}

class DriversLoaded extends DriversState {
  DriversLoaded(this.snapshot, {required this.hasMore});
  final QuerySnapshot<Map<String, dynamic>> snapshot;
  final bool hasMore;
}

class DriversFailure extends DriversState {
  DriversFailure(this.message);
  final String message;
}

class DriversBloc extends Bloc<DriversEvent, DriversState> {
  DriversBloc(this._repository) : super(DriversInitial()) {
    on<DriversStarted>(_onStarted);
    on<DriversLoadMoreRequested>(_onLoadMoreRequested);
    on<_DriversSnapshotReceived>(_onSnapshot);
    on<_DriversSnapshotFailed>(_onFailure);
    on<DriverApproved>(_onApproved);
    on<DriverSuspended>(_onSuspended);
    on<DriverRejected>(_onRejected);
  }

  static const pageSize = 30;

  final DriversRepository _repository;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  String _schoolId = '';
  int _limit = pageSize;

  Future<void> _onStarted(
    DriversStarted event,
    Emitter<DriversState> emit,
  ) async {
    emit(DriversLoading());
    _schoolId = event.schoolId;
    _limit = pageSize;
    await _subscribe();
  }

  Future<void> _onLoadMoreRequested(
    DriversLoadMoreRequested event,
    Emitter<DriversState> emit,
  ) async {
    _limit += pageSize;
    await _subscribe();
  }

  Future<void> _subscribe() async {
    await _subscription?.cancel();
    _subscription = _repository
        .watchDrivers(_schoolId, limit: _limit)
        .listen(
          (snapshot) => add(_DriversSnapshotReceived(snapshot)),
          onError: (Object error) =>
              add(_DriversSnapshotFailed(error.toString())),
        );
  }

  void _onSnapshot(_DriversSnapshotReceived event, Emitter<DriversState> emit) {
    emit(
      DriversLoaded(event.snapshot, hasMore: event.snapshot.docs.length >= _limit),
    );
  }

  void _onFailure(_DriversSnapshotFailed event, Emitter<DriversState> emit) {
    emit(DriversFailure(event.message));
  }

  Future<void> _onApproved(
    DriverApproved event,
    Emitter<DriversState> emit,
  ) async {
    try {
      await _repository.approveDriver(schoolId: event.schoolId, uid: event.uid);
    } catch (e) {
      emit(DriversFailure(e.toString()));
    }
  }

  Future<void> _onSuspended(
    DriverSuspended event,
    Emitter<DriversState> emit,
  ) async {
    try {
      await _repository.suspendDriver(
        schoolId: event.schoolId,
        uid: event.uid,
        reason: event.reason,
      );
    } catch (e) {
      emit(DriversFailure(e.toString()));
    }
  }

  Future<void> _onRejected(
    DriverRejected event,
    Emitter<DriversState> emit,
  ) async {
    try {
      await _repository.rejectDriver(
        schoolId: event.schoolId,
        uid: event.uid,
        reason: event.reason,
      );
    } catch (e) {
      emit(DriversFailure(e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

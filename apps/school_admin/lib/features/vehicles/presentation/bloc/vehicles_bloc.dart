import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/vehicles_repository.dart';

abstract class VehiclesEvent {}

class VehiclesStarted extends VehiclesEvent {
  VehiclesStarted(this.schoolId);
  final String schoolId;
}

class _VehiclesSnapshotReceived extends VehiclesEvent {
  _VehiclesSnapshotReceived(this.snapshot);
  final QuerySnapshot<Map<String, dynamic>> snapshot;
}

class _VehiclesSnapshotFailed extends VehiclesEvent {
  _VehiclesSnapshotFailed(this.message);
  final String message;
}

abstract class VehiclesState {}

class VehiclesInitial extends VehiclesState {}

class VehiclesLoading extends VehiclesState {}

class VehiclesLoaded extends VehiclesState {
  VehiclesLoaded(this.snapshot);
  final QuerySnapshot<Map<String, dynamic>> snapshot;
}

class VehiclesFailure extends VehiclesState {
  VehiclesFailure(this.message);
  final String message;
}

/// The fleet list behind [VehicleManagementPage] — read-only; every
/// mutation happens on the per-bus detail page through
/// [VehicleDetailBloc], so this bloc has no action events of its own.
class VehiclesBloc extends Bloc<VehiclesEvent, VehiclesState> {
  VehiclesBloc(this._repository) : super(VehiclesInitial()) {
    on<VehiclesStarted>(_onStarted);
    on<_VehiclesSnapshotReceived>(_onSnapshot);
    on<_VehiclesSnapshotFailed>(_onFailure);
  }

  final VehiclesRepository _repository;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  Future<void> _onStarted(
    VehiclesStarted event,
    Emitter<VehiclesState> emit,
  ) async {
    emit(VehiclesLoading());

    await _subscription?.cancel();

    _subscription = _repository
        .watchBuses(event.schoolId)
        .listen(
          (snapshot) => add(_VehiclesSnapshotReceived(snapshot)),
          onError: (Object error) =>
              add(_VehiclesSnapshotFailed(error.toString())),
        );
  }

  void _onSnapshot(
    _VehiclesSnapshotReceived event,
    Emitter<VehiclesState> emit,
  ) {
    emit(VehiclesLoaded(event.snapshot));
  }

  void _onFailure(_VehiclesSnapshotFailed event, Emitter<VehiclesState> emit) {
    emit(VehiclesFailure(event.message));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

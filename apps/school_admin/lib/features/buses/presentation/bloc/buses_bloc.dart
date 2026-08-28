import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/buses_repository.dart';

abstract class BusesEvent {}

class BusesStarted extends BusesEvent {
  BusesStarted(this.schoolId);
  final String schoolId;
}

class BusStatusChanged extends BusesEvent {
  BusStatusChanged({
    required this.schoolId,
    required this.busId,
    required this.active,
  });

  final String schoolId;
  final String busId;
  final bool active;
}

class BusCreated extends BusesEvent {
  BusCreated({
    required this.schoolId,
    required this.name,
    required this.plateNumber,
    this.capacity,
  });

  final String schoolId;
  final String name;
  final String plateNumber;
  final int? capacity;
}

class _BusesSnapshotReceived extends BusesEvent {
  _BusesSnapshotReceived(this.snapshot);
  final QuerySnapshot<Map<String, dynamic>> snapshot;
}

class _BusesSnapshotFailed extends BusesEvent {
  _BusesSnapshotFailed(this.message);
  final String message;
}

abstract class BusesState {}

class BusesInitial extends BusesState {}

class BusesLoading extends BusesState {}

class BusesLoaded extends BusesState {
  BusesLoaded(this.snapshot);
  final QuerySnapshot<Map<String, dynamic>> snapshot;
}

class BusesFailure extends BusesState {
  BusesFailure(this.message);
  final String message;
}

class BusesBloc extends Bloc<BusesEvent, BusesState> {
  BusesBloc(this._repository) : super(BusesInitial()) {
    on<BusesStarted>(_onStarted);
    on<_BusesSnapshotReceived>(_onSnapshot);
    on<_BusesSnapshotFailed>(_onFailure);
    on<BusStatusChanged>(_onStatusChanged);
    on<BusCreated>(_onCreated);
  }

  final BusesRepository _repository;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  Future<void> _onStarted(BusesStarted event, Emitter<BusesState> emit) async {
    emit(BusesLoading());

    await _subscription?.cancel();

    _subscription = _repository
        .watchBuses(event.schoolId)
        .listen(
          (snapshot) => add(_BusesSnapshotReceived(snapshot)),
          onError: (Object error) =>
              add(_BusesSnapshotFailed(error.toString())),
        );
  }

  void _onSnapshot(_BusesSnapshotReceived event, Emitter<BusesState> emit) {
    emit(BusesLoaded(event.snapshot));
  }

  void _onFailure(_BusesSnapshotFailed event, Emitter<BusesState> emit) {
    emit(BusesFailure(event.message));
  }

  Future<void> _onStatusChanged(
    BusStatusChanged event,
    Emitter<BusesState> emit,
  ) async {
    try {
      await _repository.setBusActive(
        schoolId: event.schoolId,
        busId: event.busId,
        active: event.active,
      );
    } catch (e) {
      emit(BusesFailure(e.toString()));
    }
  }

  Future<void> _onCreated(BusCreated event, Emitter<BusesState> emit) async {
    try {
      await _repository.createBus(
        schoolId: event.schoolId,
        name: event.name,
        plateNumber: event.plateNumber,
        capacity: event.capacity,
      );
    } catch (e) {
      emit(BusesFailure(e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

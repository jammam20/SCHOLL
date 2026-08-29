import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/pickup_points_repository.dart';

abstract class PickupPointsEvent {}

class PickupPointsStarted extends PickupPointsEvent {
  PickupPointsStarted(this.schoolId);
  final String schoolId;
}

class PickupPointCreated extends PickupPointsEvent {
  PickupPointCreated({
    required this.schoolId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.routeId,
    this.radiusMeters = 100,
  });

  final String schoolId;
  final String name;
  final double latitude;
  final double longitude;
  final String? routeId;
  final double radiusMeters;
}

class PickupPointUpdated extends PickupPointsEvent {
  PickupPointUpdated({
    required this.schoolId,
    required this.pickupPointId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.isActive,
    this.routeId,
    this.radiusMeters = 100,
  });

  final String schoolId;
  final String pickupPointId;
  final String name;
  final double latitude;
  final double longitude;
  final bool isActive;
  final String? routeId;
  final double radiusMeters;
}

class PickupPointStatusChanged extends PickupPointsEvent {
  PickupPointStatusChanged({
    required this.schoolId,
    required this.pickupPointId,
    required this.isActive,
  });

  final String schoolId;
  final String pickupPointId;
  final bool isActive;
}

class PickupPointDeleted extends PickupPointsEvent {
  PickupPointDeleted({required this.schoolId, required this.pickupPointId});
  final String schoolId;
  final String pickupPointId;
}

class StudentPickupPointAssigned extends PickupPointsEvent {
  StudentPickupPointAssigned({
    required this.schoolId,
    required this.studentId,
    required this.pickupPointId,
  });

  final String schoolId;
  final String studentId;
  final String? pickupPointId;
}

class _PickupPointsSnapshotReceived extends PickupPointsEvent {
  _PickupPointsSnapshotReceived(this.snapshot);
  final QuerySnapshot<Map<String, dynamic>> snapshot;
}

class _PickupPointsSnapshotFailed extends PickupPointsEvent {
  _PickupPointsSnapshotFailed(this.message);
  final String message;
}

abstract class PickupPointsState {}

class PickupPointsInitial extends PickupPointsState {}

class PickupPointsLoading extends PickupPointsState {}

class PickupPointsLoaded extends PickupPointsState {
  PickupPointsLoaded(this.snapshot, {this.actionError});
  final QuerySnapshot<Map<String, dynamic>> snapshot;

  /// Set for exactly one emission after a write fails, so the list stays
  /// on screen while the error surfaces as a snackbar.
  final String? actionError;
}

class PickupPointsFailure extends PickupPointsState {
  PickupPointsFailure(this.message);
  final String message;
}

class PickupPointsBloc extends Bloc<PickupPointsEvent, PickupPointsState> {
  PickupPointsBloc(this._repository) : super(PickupPointsInitial()) {
    on<PickupPointsStarted>(_onStarted);
    on<_PickupPointsSnapshotReceived>(_onSnapshot);
    on<_PickupPointsSnapshotFailed>(_onFailure);
    on<PickupPointCreated>(_onCreated);
    on<PickupPointUpdated>(_onUpdated);
    on<PickupPointStatusChanged>(_onStatusChanged);
    on<PickupPointDeleted>(_onDeleted);
    on<StudentPickupPointAssigned>(_onStudentAssigned);
  }

  final PickupPointsRepository _repository;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  QuerySnapshot<Map<String, dynamic>>? _lastSnapshot;

  Future<void> _onStarted(
    PickupPointsStarted event,
    Emitter<PickupPointsState> emit,
  ) async {
    emit(PickupPointsLoading());

    await _subscription?.cancel();

    _subscription = _repository
        .watchPickupPoints(event.schoolId)
        .listen(
          (snapshot) => add(_PickupPointsSnapshotReceived(snapshot)),
          onError: (Object error) =>
              add(_PickupPointsSnapshotFailed(error.toString())),
        );
  }

  void _onSnapshot(
    _PickupPointsSnapshotReceived event,
    Emitter<PickupPointsState> emit,
  ) {
    _lastSnapshot = event.snapshot;
    emit(PickupPointsLoaded(event.snapshot));
  }

  void _onFailure(
    _PickupPointsSnapshotFailed event,
    Emitter<PickupPointsState> emit,
  ) {
    emit(PickupPointsFailure(event.message));
  }

  void _emitActionError(Emitter<PickupPointsState> emit, Object error) {
    final snapshot = _lastSnapshot;
    if (snapshot == null) {
      emit(PickupPointsFailure(error.toString()));
      return;
    }
    emit(PickupPointsLoaded(snapshot, actionError: error.toString()));
  }

  Future<void> _onCreated(
    PickupPointCreated event,
    Emitter<PickupPointsState> emit,
  ) async {
    try {
      await _repository.createPickupPoint(
        schoolId: event.schoolId,
        name: event.name,
        latitude: event.latitude,
        longitude: event.longitude,
        routeId: event.routeId,
        radiusMeters: event.radiusMeters,
      );
    } catch (e) {
      _emitActionError(emit, e);
    }
  }

  Future<void> _onUpdated(
    PickupPointUpdated event,
    Emitter<PickupPointsState> emit,
  ) async {
    try {
      await _repository.updatePickupPoint(
        schoolId: event.schoolId,
        pickupPointId: event.pickupPointId,
        name: event.name,
        latitude: event.latitude,
        longitude: event.longitude,
        routeId: event.routeId,
        radiusMeters: event.radiusMeters,
        isActive: event.isActive,
      );
    } catch (e) {
      _emitActionError(emit, e);
    }
  }

  Future<void> _onStatusChanged(
    PickupPointStatusChanged event,
    Emitter<PickupPointsState> emit,
  ) async {
    try {
      await _repository.setPickupPointActive(
        schoolId: event.schoolId,
        pickupPointId: event.pickupPointId,
        isActive: event.isActive,
      );
    } catch (e) {
      _emitActionError(emit, e);
    }
  }

  Future<void> _onDeleted(
    PickupPointDeleted event,
    Emitter<PickupPointsState> emit,
  ) async {
    try {
      await _repository.deletePickupPoint(
        schoolId: event.schoolId,
        pickupPointId: event.pickupPointId,
      );
    } catch (e) {
      _emitActionError(emit, e);
    }
  }

  Future<void> _onStudentAssigned(
    StudentPickupPointAssigned event,
    Emitter<PickupPointsState> emit,
  ) async {
    try {
      await _repository.assignStudentToPickupPoint(
        schoolId: event.schoolId,
        studentId: event.studentId,
        pickupPointId: event.pickupPointId,
      );
    } catch (e) {
      _emitActionError(emit, e);
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

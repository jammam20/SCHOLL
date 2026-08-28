import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/routes_repository.dart';

abstract class RoutesEvent {}

class RoutesStarted extends RoutesEvent {
  RoutesStarted(this.schoolId);
  final String schoolId;
}

class RouteCreated extends RoutesEvent {
  RouteCreated({required this.schoolId, required this.name, this.description});

  final String schoolId;
  final String name;
  final String? description;
}

class _RoutesSnapshotReceived extends RoutesEvent {
  _RoutesSnapshotReceived(this.snapshot);
  final QuerySnapshot<Map<String, dynamic>> snapshot;
}

class _RoutesSnapshotFailed extends RoutesEvent {
  _RoutesSnapshotFailed(this.message);
  final String message;
}

abstract class RoutesState {}

class RoutesInitial extends RoutesState {}

class RoutesLoading extends RoutesState {}

class RoutesLoaded extends RoutesState {
  RoutesLoaded(this.snapshot);
  final QuerySnapshot<Map<String, dynamic>> snapshot;
}

class RoutesFailure extends RoutesState {
  RoutesFailure(this.message);
  final String message;
}

class RoutesBloc extends Bloc<RoutesEvent, RoutesState> {
  RoutesBloc(this._repository) : super(RoutesInitial()) {
    on<RoutesStarted>(_onStarted);
    on<_RoutesSnapshotReceived>(_onSnapshot);
    on<_RoutesSnapshotFailed>(_onFailure);
    on<RouteCreated>(_onCreated);
  }

  final RoutesRepository _repository;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  Future<void> _onStarted(
    RoutesStarted event,
    Emitter<RoutesState> emit,
  ) async {
    emit(RoutesLoading());

    await _subscription?.cancel();

    _subscription = _repository
        .watchRoutes(event.schoolId)
        .listen(
          (snapshot) => add(_RoutesSnapshotReceived(snapshot)),
          onError: (Object error) =>
              add(_RoutesSnapshotFailed(error.toString())),
        );
  }

  void _onSnapshot(_RoutesSnapshotReceived event, Emitter<RoutesState> emit) {
    emit(RoutesLoaded(event.snapshot));
  }

  void _onFailure(_RoutesSnapshotFailed event, Emitter<RoutesState> emit) {
    emit(RoutesFailure(event.message));
  }

  Future<void> _onCreated(RouteCreated event, Emitter<RoutesState> emit) async {
    try {
      await _repository.createRoute(
        schoolId: event.schoolId,
        name: event.name,
        description: event.description,
      );
    } catch (e) {
      emit(RoutesFailure(e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

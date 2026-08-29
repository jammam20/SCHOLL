import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/incidents_repository.dart';

abstract class IncidentsEvent {}

class IncidentsStarted extends IncidentsEvent {
  IncidentsStarted(this.schoolId);
  final String schoolId;
}

/// Re-subscribes with a bigger page size — see IncidentsBloc.pageSize.
class IncidentsLoadMoreRequested extends IncidentsEvent {}

class IncidentAcknowledged extends IncidentsEvent {
  IncidentAcknowledged({required this.schoolId, required this.incidentId});
  final String schoolId;
  final String incidentId;
}

class IncidentResolved extends IncidentsEvent {
  IncidentResolved({
    required this.schoolId,
    required this.incidentId,
    required this.resolutionNotes,
  });

  final String schoolId;
  final String incidentId;
  final String resolutionNotes;
}

class _IncidentsSnapshotReceived extends IncidentsEvent {
  _IncidentsSnapshotReceived(this.snapshot);
  final QuerySnapshot<Map<String, dynamic>> snapshot;
}

class _IncidentsSnapshotFailed extends IncidentsEvent {
  _IncidentsSnapshotFailed(this.message);
  final String message;
}

abstract class IncidentsState {}

class IncidentsInitial extends IncidentsState {}

class IncidentsLoading extends IncidentsState {}

class IncidentsLoaded extends IncidentsState {
  IncidentsLoaded(this.snapshot, {required this.hasMore});
  final QuerySnapshot<Map<String, dynamic>> snapshot;
  final bool hasMore;
}

class IncidentsFailure extends IncidentsState {
  IncidentsFailure(this.message);
  final String message;
}

/// An acknowledge/resolve that failed *after* the list already loaded —
/// emitted alongside the last good snapshot so a failed action surfaces as
/// a snackbar without blanking out the table the admin is looking at.
/// (The existing blocs emit a bare XFailure for this, which is fine for a
/// full-screen list but would be destructive for a wide data table mid-
/// triage.)
class IncidentsActionFailure extends IncidentsState {
  IncidentsActionFailure(this.message, this.snapshot, {required this.hasMore});
  final String message;
  final QuerySnapshot<Map<String, dynamic>>? snapshot;
  final bool hasMore;
}

class IncidentsBloc extends Bloc<IncidentsEvent, IncidentsState> {
  IncidentsBloc(this._repository) : super(IncidentsInitial()) {
    on<IncidentsStarted>(_onStarted);
    on<IncidentsLoadMoreRequested>(_onLoadMoreRequested);
    on<_IncidentsSnapshotReceived>(_onSnapshot);
    on<_IncidentsSnapshotFailed>(_onFailure);
    on<IncidentAcknowledged>(_onAcknowledged);
    on<IncidentResolved>(_onResolved);
  }

  static const pageSize = 100;

  final IncidentsRepository _repository;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  String _schoolId = '';
  int _limit = pageSize;
  QuerySnapshot<Map<String, dynamic>>? _lastSnapshot;

  Future<void> _onStarted(
    IncidentsStarted event,
    Emitter<IncidentsState> emit,
  ) async {
    emit(IncidentsLoading());
    _schoolId = event.schoolId;
    _limit = pageSize;
    await _subscribe();
  }

  Future<void> _onLoadMoreRequested(
    IncidentsLoadMoreRequested event,
    Emitter<IncidentsState> emit,
  ) async {
    _limit += pageSize;
    await _subscribe();
  }

  Future<void> _subscribe() async {
    await _subscription?.cancel();
    _subscription = _repository
        .watchIncidents(_schoolId, limit: _limit)
        .listen(
          (snapshot) => add(_IncidentsSnapshotReceived(snapshot)),
          onError: (Object error) =>
              add(_IncidentsSnapshotFailed(error.toString())),
        );
  }

  void _onSnapshot(
    _IncidentsSnapshotReceived event,
    Emitter<IncidentsState> emit,
  ) {
    _lastSnapshot = event.snapshot;
    emit(
      IncidentsLoaded(
        event.snapshot,
        hasMore: event.snapshot.docs.length >= _limit,
      ),
    );
  }

  void _onFailure(
    _IncidentsSnapshotFailed event,
    Emitter<IncidentsState> emit,
  ) {
    emit(IncidentsFailure(event.message));
  }

  Future<void> _onAcknowledged(
    IncidentAcknowledged event,
    Emitter<IncidentsState> emit,
  ) async {
    try {
      await _repository.acknowledgeIncident(
        schoolId: event.schoolId,
        incidentId: event.incidentId,
      );
    } catch (e) {
      emit(
        IncidentsActionFailure(
          e.toString(),
          _lastSnapshot,
          hasMore: (_lastSnapshot?.docs.length ?? 0) >= _limit,
        ),
      );
    }
  }

  Future<void> _onResolved(
    IncidentResolved event,
    Emitter<IncidentsState> emit,
  ) async {
    try {
      await _repository.resolveIncident(
        schoolId: event.schoolId,
        incidentId: event.incidentId,
        resolutionNotes: event.resolutionNotes,
      );
    } catch (e) {
      emit(
        IncidentsActionFailure(
          e.toString(),
          _lastSnapshot,
          hasMore: (_lastSnapshot?.docs.length ?? 0) >= _limit,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

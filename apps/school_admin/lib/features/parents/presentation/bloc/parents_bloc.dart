import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/parents_repository.dart';

abstract class ParentsEvent {}

class ParentsStarted extends ParentsEvent {
  ParentsStarted(this.schoolId);
  final String schoolId;
}

/// Re-subscribes with a bigger page size — see ParentsBloc.pageSize.
class ParentsLoadMoreRequested extends ParentsEvent {}

class ParentApproved extends ParentsEvent {
  ParentApproved(this.schoolId, this.uid);
  final String schoolId;
  final String uid;
}

class ParentSuspended extends ParentsEvent {
  ParentSuspended(this.schoolId, this.uid);
  final String schoolId;
  final String uid;
}

class ParentRejected extends ParentsEvent {
  ParentRejected(this.schoolId, this.uid);
  final String schoolId;
  final String uid;
}

class _ParentsSnapshotReceived extends ParentsEvent {
  _ParentsSnapshotReceived(this.snapshot);
  final QuerySnapshot<Map<String, dynamic>> snapshot;
}

class _ParentsSnapshotFailed extends ParentsEvent {
  _ParentsSnapshotFailed(this.message);
  final String message;
}

abstract class ParentsState {}

class ParentsInitial extends ParentsState {}

class ParentsLoading extends ParentsState {}

class ParentsLoaded extends ParentsState {
  ParentsLoaded(this.snapshot, {required this.hasMore});
  final QuerySnapshot<Map<String, dynamic>> snapshot;
  final bool hasMore;
}

class ParentsFailure extends ParentsState {
  ParentsFailure(this.message);
  final String message;
}

class ParentsBloc extends Bloc<ParentsEvent, ParentsState> {
  ParentsBloc(this._repository) : super(ParentsInitial()) {
    on<ParentsStarted>(_onStarted);
    on<ParentsLoadMoreRequested>(_onLoadMoreRequested);
    on<_ParentsSnapshotReceived>(_onSnapshot);
    on<_ParentsSnapshotFailed>(_onFailure);
    on<ParentApproved>(_onApproved);
    on<ParentSuspended>(_onSuspended);
    on<ParentRejected>(_onRejected);
  }

  static const pageSize = 30;

  final ParentsRepository _repository;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  String _schoolId = '';
  int _limit = pageSize;

  Future<void> _onStarted(
    ParentsStarted event,
    Emitter<ParentsState> emit,
  ) async {
    emit(ParentsLoading());
    _schoolId = event.schoolId;
    _limit = pageSize;
    await _subscribe();
  }

  Future<void> _onLoadMoreRequested(
    ParentsLoadMoreRequested event,
    Emitter<ParentsState> emit,
  ) async {
    _limit += pageSize;
    await _subscribe();
  }

  Future<void> _subscribe() async {
    await _subscription?.cancel();
    _subscription = _repository
        .watchParents(_schoolId, limit: _limit)
        .listen(
          (snapshot) => add(_ParentsSnapshotReceived(snapshot)),
          onError: (Object error) =>
              add(_ParentsSnapshotFailed(error.toString())),
        );
  }

  void _onSnapshot(_ParentsSnapshotReceived event, Emitter<ParentsState> emit) {
    emit(
      ParentsLoaded(event.snapshot, hasMore: event.snapshot.docs.length >= _limit),
    );
  }

  void _onFailure(_ParentsSnapshotFailed event, Emitter<ParentsState> emit) {
    emit(ParentsFailure(event.message));
  }

  Future<void> _onApproved(
    ParentApproved event,
    Emitter<ParentsState> emit,
  ) async {
    try {
      await _repository.approveParent(schoolId: event.schoolId, uid: event.uid);
    } catch (e) {
      emit(ParentsFailure(e.toString()));
    }
  }

  Future<void> _onSuspended(
    ParentSuspended event,
    Emitter<ParentsState> emit,
  ) async {
    try {
      await _repository.suspendParent(schoolId: event.schoolId, uid: event.uid);
    } catch (e) {
      emit(ParentsFailure(e.toString()));
    }
  }

  Future<void> _onRejected(
    ParentRejected event,
    Emitter<ParentsState> emit,
  ) async {
    try {
      await _repository.rejectParent(schoolId: event.schoolId, uid: event.uid);
    } catch (e) {
      emit(ParentsFailure(e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

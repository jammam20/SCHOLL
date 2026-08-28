import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/students_repository.dart';

abstract class StudentsEvent {}

class StudentsStarted extends StudentsEvent {
  StudentsStarted(this.schoolId);
  final String schoolId;
}

/// Re-subscribes with a bigger page size — see StudentsBloc.pageSize.
class StudentsLoadMoreRequested extends StudentsEvent {}

class StudentStatusChanged extends StudentsEvent {
  StudentStatusChanged({
    required this.schoolId,
    required this.studentId,
    required this.active,
  });

  final String schoolId;
  final String studentId;
  final bool active;
}

class StudentCreated extends StudentsEvent {
  StudentCreated({
    required this.schoolId,
    required this.name,
    required this.grade,
    this.parentId,
    this.phone,
  });

  final String schoolId;
  final String name;
  final String grade;
  final String? parentId;
  final String? phone;
}

class StudentRouteAssigned extends StudentsEvent {
  StudentRouteAssigned({
    required this.schoolId,
    required this.studentId,
    required this.routeId,
  });

  final String schoolId;
  final String studentId;
  final String? routeId;
}

class StudentLocationChanged extends StudentsEvent {
  StudentLocationChanged({
    required this.schoolId,
    required this.studentId,
    required this.latitude,
    required this.longitude,
  });

  final String schoolId;
  final String studentId;
  final double latitude;
  final double longitude;
}

class StudentApproved extends StudentsEvent {
  StudentApproved({required this.schoolId, required this.studentId});
  final String schoolId;
  final String studentId;
}

class StudentRejected extends StudentsEvent {
  StudentRejected({required this.schoolId, required this.studentId});
  final String schoolId;
  final String studentId;
}

class StudentParentLinked extends StudentsEvent {
  StudentParentLinked({
    required this.schoolId,
    required this.studentId,
    required this.parentUid,
  });

  final String schoolId;
  final String studentId;
  final String parentUid;
}

class StudentParentUnlinked extends StudentsEvent {
  StudentParentUnlinked({
    required this.schoolId,
    required this.studentId,
    required this.parentUid,
  });

  final String schoolId;
  final String studentId;
  final String parentUid;
}

class _StudentsSnapshotReceived extends StudentsEvent {
  _StudentsSnapshotReceived(this.snapshot);
  final QuerySnapshot<Map<String, dynamic>> snapshot;
}

class _StudentsSnapshotFailed extends StudentsEvent {
  _StudentsSnapshotFailed(this.message);
  final String message;
}

abstract class StudentsState {}

class StudentsInitial extends StudentsState {}

class StudentsLoading extends StudentsState {}

class StudentsLoaded extends StudentsState {
  StudentsLoaded(this.snapshot, {required this.hasMore});
  final QuerySnapshot<Map<String, dynamic>> snapshot;
  // True when the last page came back full, meaning there are likely more
  // students beyond the current limit — an approximation (a school with
  // exactly a multiple of pageSize students shows one harmless extra "Load
  // more" tap that returns nothing new), not a real total count, but cheap
  // and good enough to drive a "Load more" button.
  final bool hasMore;
}

class StudentsFailure extends StudentsState {
  StudentsFailure(this.message);
  final String message;
}

class StudentsBloc extends Bloc<StudentsEvent, StudentsState> {
  StudentsBloc(this._repository) : super(StudentsInitial()) {
    on<StudentsStarted>(_onStarted);
    on<StudentsLoadMoreRequested>(_onLoadMoreRequested);
    on<_StudentsSnapshotReceived>(_onSnapshotReceived);
    on<_StudentsSnapshotFailed>(_onSnapshotFailed);
    on<StudentStatusChanged>(_onStatusChanged);
    on<StudentCreated>(_onCreated);
    on<StudentRouteAssigned>(_onRouteAssigned);
    on<StudentLocationChanged>(_onLocationChanged);
    on<StudentApproved>(_onApproved);
    on<StudentRejected>(_onRejected);
    on<StudentParentLinked>(_onParentLinked);
    on<StudentParentUnlinked>(_onParentUnlinked);
  }

  static const pageSize = 30;

  final StudentsRepository _repository;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  String _schoolId = '';
  int _limit = pageSize;

  Future<void> _onStarted(
    StudentsStarted event,
    Emitter<StudentsState> emit,
  ) async {
    emit(StudentsLoading());
    _schoolId = event.schoolId;
    _limit = pageSize;
    await _subscribe();
  }

  Future<void> _onLoadMoreRequested(
    StudentsLoadMoreRequested event,
    Emitter<StudentsState> emit,
  ) async {
    _limit += pageSize;
    await _subscribe();
  }

  Future<void> _subscribe() async {
    await _subscription?.cancel();
    _subscription = _repository
        .watchStudents(_schoolId, limit: _limit)
        .listen(
          (snapshot) => add(_StudentsSnapshotReceived(snapshot)),
          onError: (Object error) =>
              add(_StudentsSnapshotFailed(error.toString())),
        );
  }

  void _onSnapshotReceived(
    _StudentsSnapshotReceived event,
    Emitter<StudentsState> emit,
  ) {
    emit(
      StudentsLoaded(event.snapshot, hasMore: event.snapshot.docs.length >= _limit),
    );
  }

  void _onSnapshotFailed(
    _StudentsSnapshotFailed event,
    Emitter<StudentsState> emit,
  ) {
    emit(StudentsFailure(event.message));
  }

  Future<void> _onStatusChanged(
    StudentStatusChanged event,
    Emitter<StudentsState> emit,
  ) async {
    try {
      await _repository.setStudentActive(
        schoolId: event.schoolId,
        studentId: event.studentId,
        active: event.active,
      );
    } catch (e) {
      emit(StudentsFailure(e.toString()));
    }
  }

  Future<void> _onCreated(
    StudentCreated event,
    Emitter<StudentsState> emit,
  ) async {
    try {
      await _repository.createStudent(
        schoolId: event.schoolId,
        name: event.name,
        grade: event.grade,
        parentId: event.parentId,
        phone: event.phone,
      );
    } catch (e) {
      emit(StudentsFailure(e.toString()));
    }
  }

  Future<void> _onRouteAssigned(
    StudentRouteAssigned event,
    Emitter<StudentsState> emit,
  ) async {
    try {
      await _repository.assignRoute(
        schoolId: event.schoolId,
        studentId: event.studentId,
        routeId: event.routeId,
      );
    } catch (e) {
      emit(StudentsFailure(e.toString()));
    }
  }

  Future<void> _onLocationChanged(
    StudentLocationChanged event,
    Emitter<StudentsState> emit,
  ) async {
    try {
      await _repository.updateStudent(
        schoolId: event.schoolId,
        studentId: event.studentId,
        data: {'latitude': event.latitude, 'longitude': event.longitude},
      );
    } catch (e) {
      emit(StudentsFailure(e.toString()));
    }
  }

  Future<void> _onApproved(
    StudentApproved event,
    Emitter<StudentsState> emit,
  ) async {
    try {
      await _repository.approveStudent(
        schoolId: event.schoolId,
        studentId: event.studentId,
      );
    } catch (e) {
      emit(StudentsFailure(e.toString()));
    }
  }

  Future<void> _onRejected(
    StudentRejected event,
    Emitter<StudentsState> emit,
  ) async {
    try {
      await _repository.deleteStudent(
        schoolId: event.schoolId,
        studentId: event.studentId,
      );
    } catch (e) {
      emit(StudentsFailure(e.toString()));
    }
  }

  Future<void> _onParentLinked(
    StudentParentLinked event,
    Emitter<StudentsState> emit,
  ) async {
    try {
      await _repository.linkParent(
        schoolId: event.schoolId,
        studentId: event.studentId,
        parentUid: event.parentUid,
      );
    } catch (e) {
      emit(StudentsFailure(e.toString()));
    }
  }

  Future<void> _onParentUnlinked(
    StudentParentUnlinked event,
    Emitter<StudentsState> emit,
  ) async {
    try {
      await _repository.unlinkParent(
        schoolId: event.schoolId,
        studentId: event.studentId,
        parentUid: event.parentUid,
      );
    } catch (e) {
      emit(StudentsFailure(e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/schools_repository.dart';

sealed class SchoolsEvent {
  const SchoolsEvent();
}

final class SchoolsStarted extends SchoolsEvent {
  const SchoolsStarted();
}

final class SchoolCreated extends SchoolsEvent {
  const SchoolCreated({
    required this.name,
    required this.code,
    this.phone,
    this.address,
  });

  final String name;
  final String code;
  final String? phone;
  final String? address;
}

final class SchoolStatusChanged extends SchoolsEvent {
  const SchoolStatusChanged({required this.schoolId, required this.active});

  final String schoolId;
  final bool active;
}

sealed class SchoolsState {
  const SchoolsState();
}

final class SchoolsInitial extends SchoolsState {
  const SchoolsInitial();
}

final class SchoolsLoading extends SchoolsState {
  const SchoolsLoading();
}

final class SchoolsLoaded extends SchoolsState {
  const SchoolsLoaded(this.snapshot);

  final QuerySnapshot<Map<String, dynamic>> snapshot;
}

final class SchoolsFailure extends SchoolsState {
  const SchoolsFailure(this.message);

  final String message;
}

final class SchoolsBloc extends Bloc<SchoolsEvent, SchoolsState> {
  SchoolsBloc(this._repository) : super(const SchoolsInitial()) {
    on<SchoolsStarted>(_onStarted);
    on<SchoolCreated>(_onCreated);
    on<SchoolStatusChanged>(_onStatusChanged);
  }

  final SchoolsRepository _repository;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  Future<void> _onStarted(
    SchoolsStarted event,
    Emitter<SchoolsState> emit,
  ) async {
    emit(const SchoolsLoading());

    await _subscription?.cancel();

    _subscription = _repository.watchSchools().listen(
      (snapshot) => add(_SchoolsSnapshotReceived(snapshot)),
      onError: (Object error, StackTrace stackTrace) {
        add(_SchoolsStreamFailed(error.toString()));
      },
    );
  }

  Future<void> _onCreated(
    SchoolCreated event,
    Emitter<SchoolsState> emit,
  ) async {
    try {
      await _repository.createSchool(
        name: event.name,
        code: event.code,
        phone: event.phone,
        address: event.address,
      );
    } catch (error) {
      emit(SchoolsFailure(error.toString()));
    }
  }

  Future<void> _onStatusChanged(
    SchoolStatusChanged event,
    Emitter<SchoolsState> emit,
  ) async {
    try {
      await _repository.setSchoolActive(event.schoolId, event.active);
    } catch (error) {
      emit(SchoolsFailure(error.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

final class _SchoolsSnapshotReceived extends SchoolsEvent {
  const _SchoolsSnapshotReceived(this.snapshot);

  final QuerySnapshot<Map<String, dynamic>> snapshot;
}

final class _SchoolsStreamFailed extends SchoolsEvent {
  const _SchoolsStreamFailed(this.message);

  final String message;
}

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

import '../../data/vehicles_repository.dart';

abstract class VehicleDetailEvent {}

class VehicleDetailStarted extends VehicleDetailEvent {
  VehicleDetailStarted({required this.schoolId, required this.busId});
  final String schoolId;
  final String busId;
}

class VehicleProfileSaved extends VehicleDetailEvent {
  VehicleProfileSaved({
    required this.schoolId,
    required this.busId,
    required this.update,
  });

  final String schoolId;
  final String busId;
  final VehicleProfileUpdate update;
}

class MaintenanceRecordAdded extends VehicleDetailEvent {
  MaintenanceRecordAdded({
    required this.schoolId,
    required this.busId,
    required this.itemType,
    required this.dueAt,
    this.description = '',
    this.notes,
  });

  final String schoolId;
  final String busId;
  final MaintenanceItemType itemType;
  final DateTime dueAt;
  final String description;
  final String? notes;
}

class MaintenanceRecordCompleted extends VehicleDetailEvent {
  MaintenanceRecordCompleted({
    required this.schoolId,
    required this.busId,
    required this.recordId,
    required this.itemType,
    this.nextDueAt,
    this.notes,
  });

  final String schoolId;
  final String busId;
  final String recordId;
  final MaintenanceItemType itemType;
  final DateTime? nextDueAt;
  final String? notes;
}

class MaintenanceRecordDeleted extends VehicleDetailEvent {
  MaintenanceRecordDeleted({
    required this.schoolId,
    required this.busId,
    required this.recordId,
  });

  final String schoolId;
  final String busId;
  final String recordId;
}

class _VehicleSnapshotReceived extends VehicleDetailEvent {
  _VehicleSnapshotReceived(this.snapshot);
  final DocumentSnapshot<Map<String, dynamic>> snapshot;
}

class _MaintenanceSnapshotReceived extends VehicleDetailEvent {
  _MaintenanceSnapshotReceived(this.snapshot);
  final QuerySnapshot<Map<String, dynamic>> snapshot;
}

class _VehicleDetailSnapshotFailed extends VehicleDetailEvent {
  _VehicleDetailSnapshotFailed(this.message);
  final String message;
}

/// Which write just finished, so the page can confirm the *specific*
/// action rather than showing one generic "saved" for everything.
enum VehicleDetailAction {
  profileSaved,
  maintenanceAdded,
  maintenanceCompleted,
  maintenanceDeleted,
}

abstract class VehicleDetailState {}

class VehicleDetailInitial extends VehicleDetailState {}

class VehicleDetailLoading extends VehicleDetailState {}

class VehicleDetailLoaded extends VehicleDetailState {
  VehicleDetailLoaded({
    required this.bus,
    required this.maintenance,
    this.actionError,
    this.completedAction,
  });

  final SchoolBus bus;
  final List<MaintenanceRecord> maintenance;

  /// Set for exactly one emission after a save/complete/delete fails, so
  /// the page can show a snackbar without losing the loaded bus it's
  /// already rendering.
  final String? actionError;

  /// Set for exactly one emission after a write actually succeeds — the
  /// page never claims success optimistically, since a Firestore write can
  /// still be rejected by rules after the button was pressed.
  final VehicleDetailAction? completedAction;
}

class VehicleDetailFailure extends VehicleDetailState {
  VehicleDetailFailure(this.message, {this.notFound = false});

  /// A raw error string from Firestore, or null when [notFound] carries
  /// the whole meaning — the page renders its own localized copy in that
  /// case rather than showing an English sentence built in the bloc.
  final String? message;
  final bool notFound;
}

/// One bus's profile plus its maintenance log, kept live from two
/// subscriptions (the bus document and its `maintenance` subcollection)
/// merged into a single loaded state — the detail page needs both at once
/// and neither is useful alone.
class VehicleDetailBloc extends Bloc<VehicleDetailEvent, VehicleDetailState> {
  VehicleDetailBloc(this._repository) : super(VehicleDetailInitial()) {
    on<VehicleDetailStarted>(_onStarted);
    on<_VehicleSnapshotReceived>(_onBusSnapshot);
    on<_MaintenanceSnapshotReceived>(_onMaintenanceSnapshot);
    on<_VehicleDetailSnapshotFailed>(_onFailure);
    on<VehicleProfileSaved>(_onProfileSaved);
    on<MaintenanceRecordAdded>(_onMaintenanceAdded);
    on<MaintenanceRecordCompleted>(_onMaintenanceCompleted);
    on<MaintenanceRecordDeleted>(_onMaintenanceDeleted);
  }

  final VehiclesRepository _repository;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _busSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _maintenanceSubscription;

  SchoolBus? _bus;
  List<MaintenanceRecord> _maintenance = const [];

  Future<void> _onStarted(
    VehicleDetailStarted event,
    Emitter<VehicleDetailState> emit,
  ) async {
    emit(VehicleDetailLoading());

    await _busSubscription?.cancel();
    await _maintenanceSubscription?.cancel();

    _busSubscription = _repository
        .watchBus(schoolId: event.schoolId, busId: event.busId)
        .listen(
          (snapshot) => add(_VehicleSnapshotReceived(snapshot)),
          onError: (Object error) =>
              add(_VehicleDetailSnapshotFailed(error.toString())),
        );

    _maintenanceSubscription = _repository
        .watchMaintenance(schoolId: event.schoolId, busId: event.busId)
        .listen(
          (snapshot) => add(_MaintenanceSnapshotReceived(snapshot)),
          onError: (Object error) =>
              add(_VehicleDetailSnapshotFailed(error.toString())),
        );
  }

  void _onBusSnapshot(
    _VehicleSnapshotReceived event,
    Emitter<VehicleDetailState> emit,
  ) {
    final data = event.snapshot.data();
    if (data == null) {
      emit(VehicleDetailFailure(null, notFound: true));
      return;
    }
    _bus = SchoolBus.fromMap(event.snapshot.id, data);
    _emitLoaded(emit);
  }

  void _onMaintenanceSnapshot(
    _MaintenanceSnapshotReceived event,
    Emitter<VehicleDetailState> emit,
  ) {
    _maintenance = event.snapshot.docs
        .map((doc) => MaintenanceRecord.fromMap(doc.id, doc.data()))
        .toList();
    _emitLoaded(emit);
  }

  /// Only emits once the bus document itself has arrived — a maintenance
  /// list with no vehicle to attach it to isn't a renderable state.
  void _emitLoaded(
    Emitter<VehicleDetailState> emit, {
    String? actionError,
    VehicleDetailAction? completedAction,
  }) {
    final bus = _bus;
    if (bus == null) return;
    emit(
      VehicleDetailLoaded(
        bus: bus,
        maintenance: _maintenance,
        actionError: actionError,
        completedAction: completedAction,
      ),
    );
  }

  void _onFailure(
    _VehicleDetailSnapshotFailed event,
    Emitter<VehicleDetailState> emit,
  ) {
    emit(VehicleDetailFailure(event.message));
  }

  Future<void> _onProfileSaved(
    VehicleProfileSaved event,
    Emitter<VehicleDetailState> emit,
  ) async {
    try {
      await _repository.updateVehicleProfile(
        schoolId: event.schoolId,
        busId: event.busId,
        update: event.update,
      );
      _emitLoaded(emit, completedAction: VehicleDetailAction.profileSaved);
    } catch (e) {
      _emitLoaded(emit, actionError: e.toString());
    }
  }

  Future<void> _onMaintenanceAdded(
    MaintenanceRecordAdded event,
    Emitter<VehicleDetailState> emit,
  ) async {
    try {
      await _repository.addMaintenanceRecord(
        schoolId: event.schoolId,
        busId: event.busId,
        itemType: event.itemType,
        dueAt: event.dueAt,
        description: event.description,
        notes: event.notes,
      );
      _emitLoaded(emit, completedAction: VehicleDetailAction.maintenanceAdded);
    } catch (e) {
      _emitLoaded(emit, actionError: e.toString());
    }
  }

  Future<void> _onMaintenanceCompleted(
    MaintenanceRecordCompleted event,
    Emitter<VehicleDetailState> emit,
  ) async {
    try {
      await _repository.completeMaintenanceRecord(
        schoolId: event.schoolId,
        busId: event.busId,
        recordId: event.recordId,
        itemType: event.itemType,
        nextDueAt: event.nextDueAt,
        notes: event.notes,
      );
      _emitLoaded(
        emit,
        completedAction: VehicleDetailAction.maintenanceCompleted,
      );
    } catch (e) {
      _emitLoaded(emit, actionError: e.toString());
    }
  }

  Future<void> _onMaintenanceDeleted(
    MaintenanceRecordDeleted event,
    Emitter<VehicleDetailState> emit,
  ) async {
    try {
      await _repository.deleteMaintenanceRecord(
        schoolId: event.schoolId,
        busId: event.busId,
        recordId: event.recordId,
      );
      _emitLoaded(
        emit,
        completedAction: VehicleDetailAction.maintenanceDeleted,
      );
    } catch (e) {
      _emitLoaded(emit, actionError: e.toString());
    }
  }

  @override
  Future<void> close() async {
    await _busSubscription?.cancel();
    await _maintenanceSubscription?.cancel();
    return super.close();
  }
}

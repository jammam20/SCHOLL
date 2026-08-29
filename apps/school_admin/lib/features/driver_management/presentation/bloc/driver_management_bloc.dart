import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

import '../../../drivers/data/drivers_repository.dart';
import '../../data/driver_profiles_repository.dart';

abstract class DriverManagementEvent {}

class DriverManagementStarted extends DriverManagementEvent {
  DriverManagementStarted(this.schoolId);
  final String schoolId;
}

class DriverProfileSaved extends DriverManagementEvent {
  DriverProfileSaved({
    required this.schoolId,
    required this.uid,
    this.licenseNumber,
    this.licenseExpiry,
    this.trainingCompletedAt,
    this.assignedBusIds,
    this.assignedRouteIds,
  });

  final String schoolId;
  final String uid;
  final String? licenseNumber;
  final DateTime? licenseExpiry;
  final DateTime? trainingCompletedAt;
  final List<String>? assignedBusIds;
  final List<String>? assignedRouteIds;
}

class _DriverMembersReceived extends DriverManagementEvent {
  _DriverMembersReceived(this.snapshot);
  final QuerySnapshot<Map<String, dynamic>> snapshot;
}

class _DriverProfilesReceived extends DriverManagementEvent {
  _DriverProfilesReceived(this.snapshot);
  final QuerySnapshot<Map<String, dynamic>> snapshot;
}

class _DriverManagementFailed extends DriverManagementEvent {
  _DriverManagementFailed(this.message);
  final String message;
}

abstract class DriverManagementState {}

class DriverManagementInitial extends DriverManagementState {}

class DriverManagementLoading extends DriverManagementState {}

class DriverManagementLoaded extends DriverManagementState {
  DriverManagementLoaded(this.drivers, {this.actionError, this.saved = false});

  final List<DriverWithProfile> drivers;
  final String? actionError;

  /// True for exactly one emission after a profile write actually
  /// succeeds — never set optimistically.
  final bool saved;
}

class DriverManagementFailure extends DriverManagementState {
  DriverManagementFailure(this.message);
  final String message;
}

/// Joins the school's driver member records to their optional
/// [DriverProfile] documents. Two independent subscriptions feed one
/// merged list, the same shape [VehicleDetailBloc] uses — the screen needs
/// both halves and a driver row without its member record (no name, no
/// approval status) isn't renderable.
class DriverManagementBloc
    extends Bloc<DriverManagementEvent, DriverManagementState> {
  DriverManagementBloc(this._drivers, this._profiles)
    : super(DriverManagementInitial()) {
    on<DriverManagementStarted>(_onStarted);
    on<_DriverMembersReceived>(_onMembers);
    on<_DriverProfilesReceived>(_onProfiles);
    on<_DriverManagementFailed>(_onFailure);
    on<DriverProfileSaved>(_onProfileSaved);
  }

  final DriversRepository _drivers;
  final DriverProfilesRepository _profiles;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _membersSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _profilesSubscription;

  QuerySnapshot<Map<String, dynamic>>? _members;
  Map<String, DriverProfile> _profilesByUid = const {};

  Future<void> _onStarted(
    DriverManagementStarted event,
    Emitter<DriverManagementState> emit,
  ) async {
    emit(DriverManagementLoading());

    await _membersSubscription?.cancel();
    await _profilesSubscription?.cancel();

    _membersSubscription = _drivers
        .watchDrivers(event.schoolId, limit: 200)
        .listen(
          (snapshot) => add(_DriverMembersReceived(snapshot)),
          onError: (Object error) =>
              add(_DriverManagementFailed(error.toString())),
        );

    _profilesSubscription = _profiles
        .watchProfiles(event.schoolId)
        .listen(
          (snapshot) => add(_DriverProfilesReceived(snapshot)),
          onError: (Object error) =>
              add(_DriverManagementFailed(error.toString())),
        );
  }

  void _onMembers(
    _DriverMembersReceived event,
    Emitter<DriverManagementState> emit,
  ) {
    _members = event.snapshot;
    _emitLoaded(emit);
  }

  void _onProfiles(
    _DriverProfilesReceived event,
    Emitter<DriverManagementState> emit,
  ) {
    _profilesByUid = {
      for (final doc in event.snapshot.docs)
        doc.id: DriverProfile.fromMap(doc.id, doc.data()),
    };
    _emitLoaded(emit);
  }

  /// Emits as soon as the member list exists, with whatever profiles have
  /// arrived — a driver whose profile hasn't loaded (or doesn't exist)
  /// renders correctly with a null profile, so there's no reason to make
  /// the whole screen wait on the second subscription.
  void _emitLoaded(
    Emitter<DriverManagementState> emit, {
    String? actionError,
    bool saved = false,
  }) {
    final members = _members;
    if (members == null) return;

    final drivers = members.docs.map((doc) {
      final data = doc.data();
      return DriverWithProfile(
        uid: doc.id,
        displayName:
            data['displayName']?.toString() ??
            data['name']?.toString() ??
            doc.id,
        status: data['status']?.toString() ?? 'pending',
        profile: _profilesByUid[doc.id],
      );
    }).toList();

    final now = DateTime.now();
    // Drivers whose paperwork needs action sort to the top; everything
    // else keeps the query's own displayName order.
    drivers.sort((a, b) {
      final aFlagged = a.needsAttention(now);
      final bFlagged = b.needsAttention(now);
      if (aFlagged != bFlagged) return aFlagged ? -1 : 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    emit(
      DriverManagementLoaded(drivers, actionError: actionError, saved: saved),
    );
  }

  void _onFailure(
    _DriverManagementFailed event,
    Emitter<DriverManagementState> emit,
  ) {
    emit(DriverManagementFailure(event.message));
  }

  Future<void> _onProfileSaved(
    DriverProfileSaved event,
    Emitter<DriverManagementState> emit,
  ) async {
    try {
      await _profiles.saveProfile(
        schoolId: event.schoolId,
        uid: event.uid,
        licenseNumber: event.licenseNumber,
        licenseExpiry: event.licenseExpiry,
        trainingCompletedAt: event.trainingCompletedAt,
        assignedBusIds: event.assignedBusIds,
        assignedRouteIds: event.assignedRouteIds,
      );
      _emitLoaded(emit, saved: true);
    } catch (e) {
      _emitLoaded(emit, actionError: e.toString());
    }
  }

  @override
  Future<void> close() async {
    await _membersSubscription?.cancel();
    await _profilesSubscription?.cancel();
    return super.close();
  }
}

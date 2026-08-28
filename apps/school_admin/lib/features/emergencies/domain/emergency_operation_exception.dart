/// Mirrors TripOperationException in the driver app — the admin app never
/// had a typed domain-exception layer before this phase (see
/// TripsBloc.updateStatus in this app, which still just does
/// `emit(TripsFailure(e.toString()))`); resolving an emergency needs one so
/// raw Firestore text ("PERMISSION_DENIED", stack traces) never reaches the
/// admin's UI.
enum EmergencyOperationError { unauthorized, emergencyNotFound, emergencyAlreadyResolved }

class EmergencyOperationException implements Exception {
  const EmergencyOperationException(this.error, this.message);

  final EmergencyOperationError error;
  final String message;

  @override
  String toString() => message;
}

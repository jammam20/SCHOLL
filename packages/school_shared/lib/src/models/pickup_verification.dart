import '../enums/pickup_verification.dart';

/// A record of one attempted student pickup verification. Deliberately
/// named/typed to never overstate what's actually checked: `qrCode`/`otp`
/// verify that whoever is collecting the student has the code the parent
/// generated for that pickup (something the authorized person was given),
/// not the person's physical identity — there is no ID-document or
/// biometric check behind this, and `driverManual` is exactly what it says:
/// the driver's own visual confirmation, recorded as an event, nothing more.
class PickupVerification {
  const PickupVerification({
    required this.id,
    required this.schoolId,
    required this.tripId,
    required this.studentId,
    required this.method,
    required this.status,
    required this.recordedAt,
    required this.driverId,
    this.authorizedPersonName,
    this.latitude,
    this.longitude,
    this.notes,
  });

  final String id;
  final String schoolId;
  final String tripId;
  final String studentId;
  final PickupVerificationMethod method;
  final PickupVerificationStatus status;
  final DateTime recordedAt;
  final String driverId;
  final String? authorizedPersonName;
  final double? latitude;
  final double? longitude;
  final String? notes;

  factory PickupVerification.fromMap(String id, Map<String, dynamic> data) {
    return PickupVerification(
      id: id,
      schoolId: data['schoolId'] as String? ?? '',
      tripId: data['tripId'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      method: PickupVerificationMethodX.tryParse(data['method']) ??
          PickupVerificationMethod.driverManual,
      status: PickupVerificationStatusX.tryParse(data['status']) ??
          PickupVerificationStatus.pending,
      recordedAt: _asDateTime(data['recordedAt']) ?? DateTime.now(),
      driverId: data['driverId'] as String? ?? '',
      authorizedPersonName: data['authorizedPersonName'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      notes: data['notes'] as String?,
    );
  }

  static DateTime? _asDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      final dynamic dynamicValue = value;
      final result = dynamicValue.toDate();
      return result is DateTime ? result : null;
    } catch (_) {
      return null;
    }
  }
}

/// A person a parent has pre-authorized to collect a student — embedded
/// directly on [Student] (a small, bounded list) rather than a separate
/// collection, since it's always read/written together with the student
/// it belongs to.
class AuthorizedPickupPerson {
  const AuthorizedPickupPerson({
    required this.id,
    required this.name,
    this.relationship,
    this.phone,
  });

  final String id;
  final String name;
  final String? relationship;
  final String? phone;

  factory AuthorizedPickupPerson.fromMap(Map<String, dynamic> data) {
    return AuthorizedPickupPerson(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      relationship: data['relationship'] as String?,
      phone: data['phone'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    if (relationship != null) 'relationship': relationship,
    if (phone != null) 'phone': phone,
  };
}

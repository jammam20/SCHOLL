import '../enums/parent_request_status.dart';

/// One message/request a parent sent to their school, at
/// `schools/{schoolId}/parentRequests/{id}` (Feature: Parent–Driver
/// communication).
///
/// The routing is deliberate and is the whole point of the collection: a
/// parent never contacts a driver directly — they write here, the school's
/// admin reads it and relays whatever the driver needs to know. There is
/// no driver-readable path to this collection in firestore.rules, and no
/// parent-visible driver phone number anywhere in the parent app, so the
/// "through the school" rule is enforced by the data model rather than by
/// convention.
///
/// Self-attested on create (`parentUid` must equal the caller's uid) and
/// append-only from the parent's side — only a school admin may later flip
/// `status`/`readBy`/`readAt`, exactly like the `absenceLog` collection
/// this one is modeled on.
class ParentRequest {
  const ParentRequest({
    required this.id,
    required this.schoolId,
    required this.parentUid,
    required this.message,
    required this.createdAt,
    required this.status,
    this.studentId,
    this.studentName,
    this.tripId,
    this.readBy,
    this.readAt,
  });

  final String id;
  final String schoolId;
  final String parentUid;
  final String message;
  final DateTime createdAt;
  final ParentRequestStatus status;

  /// Which child this is about, when it's about one — a parent can also
  /// ask a general question that isn't tied to a specific student.
  final String? studentId;

  /// Denormalized at write time so an admin's queue can name the child
  /// without a second read (mirrors the `studentName` already denormalized
  /// onto `absenceLog` entries for the same reason).
  final String? studentName;

  /// Optional context: the specific trip the parent is asking about.
  final String? tripId;

  /// Set by the school admin who picked the request up — never by a parent.
  final String? readBy;
  final DateTime? readAt;

  factory ParentRequest.fromMap(String id, Map<String, dynamic> data) {
    return ParentRequest(
      id: id,
      schoolId: data['schoolId'] as String? ?? '',
      parentUid: data['parentUid'] as String? ?? '',
      message: data['message'] as String? ?? '',
      createdAt: _asDateTime(data['createdAt']) ?? DateTime.now(),
      status:
          ParentRequestStatusX.tryParse(data['status']) ??
          ParentRequestStatus.open,
      studentId: data['studentId'] as String?,
      studentName: data['studentName'] as String?,
      tripId: data['tripId'] as String?,
      readBy: data['readBy'] as String?,
      readAt: _asDateTime(data['readAt']),
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

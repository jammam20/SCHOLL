import '../enums/parent_request_status.dart';

/// One conversation thread between a parent and their school, at
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
/// This is a real, continuing thread, not a one-shot message: the actual
/// back-and-forth lives in the `messages` subcollection
/// ([ParentThreadMessage]); this document is the thread's own summary
/// (subject, who it's about, when it last moved, who still has something
/// unread) so an inbox list never needs to read every message just to
/// render itself. `message`/`createdAt` are the thread's original opening
/// message, kept on the thread doc itself for a cheap first-line preview.
class ParentRequest {
  const ParentRequest({
    required this.id,
    required this.schoolId,
    required this.parentUid,
    required this.subject,
    required this.message,
    required this.createdAt,
    required this.status,
    this.studentId,
    this.studentName,
    this.tripId,
    this.readBy,
    this.readAt,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.unreadByAdmin = true,
    this.unreadByParent = false,
  });

  final String id;
  final String schoolId;
  final String parentUid;

  /// A short title for the thread — shown in the admin inbox list and the
  /// parent's own thread list, distinct from the full message body.
  final String subject;
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

  /// Kept in sync by the onParentMessageCreated Cloud Function on every new
  /// message, from either side — see functions/src/index.ts.
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;

  /// Whether the admin/parent side has a message here they haven't seen
  /// yet. Flipped server-side (onParentMessageCreated) whenever the other
  /// side sends a message; a client only ever clears its own flag, on
  /// opening the thread.
  final bool unreadByAdmin;
  final bool unreadByParent;

  factory ParentRequest.fromMap(String id, Map<String, dynamic> data) {
    return ParentRequest(
      id: id,
      schoolId: data['schoolId'] as String? ?? '',
      parentUid: data['parentUid'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
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
      lastMessageAt: _asDateTime(data['lastMessageAt']),
      lastMessagePreview: data['lastMessagePreview'] as String?,
      unreadByAdmin: data['unreadByAdmin'] != false,
      unreadByParent: data['unreadByParent'] == true,
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

/// One message in a [ParentRequest] thread's `messages` subcollection.
class ParentThreadMessage {
  const ParentThreadMessage({
    required this.id,
    required this.senderUid,
    required this.senderRole,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String senderUid;

  /// 'parent' or 'admin' — a plain string (not a shared UserRole value)
  /// since only these two roles can ever appear in this thread by rule.
  final String senderRole;
  final String text;
  final DateTime createdAt;

  bool get isFromParent => senderRole == 'parent';

  factory ParentThreadMessage.fromMap(String id, Map<String, dynamic> data) {
    return ParentThreadMessage(
      id: id,
      senderUid: data['senderUid'] as String? ?? '',
      senderRole: data['senderRole'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: _asDateTime(data['createdAt']) ?? DateTime.now(),
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

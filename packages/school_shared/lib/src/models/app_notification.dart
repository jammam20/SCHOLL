/// One entry in a user's in-app notification inbox, at
/// `users/{uid}/notifications/{id}`. Written server-side (Cloud Functions,
/// `functions/src/index.ts`) at the same moment a push is sent, using the
/// same event-type/dedup logic already in place for FCM — this just gives
/// that existing event stream a durable, readable history instead of only
/// a transient push. `type` mirrors the `data.type` payload already sent
/// with each push (see `TRIP_STATUS_NOTIFICATIONS` in the functions code).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.schoolId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.tripId,
    this.busId,
    this.studentId,
  });

  final String id;
  final String schoolId;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  final String? tripId;
  final String? busId;
  final String? studentId;

  factory AppNotification.fromMap(String id, Map<String, dynamic> data) {
    return AppNotification(
      id: id,
      schoolId: data['schoolId'] as String? ?? '',
      type: data['type'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      createdAt: _asDateTime(data['createdAt']) ?? DateTime.now(),
      read: data['read'] == true,
      tripId: data['tripId'] as String?,
      busId: data['busId'] as String?,
      studentId: data['studentId'] as String?,
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

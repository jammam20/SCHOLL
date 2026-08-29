import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_shared/school_shared.dart';

/// Reader for the in-app notification inbox at
/// `users/{uid}/notifications/{id}` (Feature: Smart Notifications).
///
/// Entries are written server-side only — the Cloud Functions in
/// `functions/src/index.ts` create one at the same moment they send the
/// matching FCM push, and firestore.rules blocks client creates/deletes
/// outright. The one write a client is allowed is flipping `read`, which is
/// exactly what [markRead]/[markAllRead] do; anything wider is rejected by
/// the `hasOnly(['read'])` allow-list on `users/{uid}/notifications/{id}`.
///
/// Separate from the existing [PushNotificationsRepository], which owns the
/// FCM *token registration* half of the same feature and nothing else.
class NotificationsRepository {
  NotificationsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Most recent first. Capped because an inbox is a "what happened lately"
  /// view, not an archive — a busy school year would otherwise stream
  /// thousands of documents into memory to render one screen.
  static const historyLimit = 100;

  Stream<List<AppNotification>> watchNotifications(String uid) {
    return _notifications(uid)
        .orderBy('createdAt', descending: true)
        .limit(historyLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppNotification.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Drives the app bar's unread badge. Deliberately a single-field
  /// equality query with no `orderBy` — that needs only the automatic
  /// single-field index, so this works against
  /// `firebase/firestore.indexes.json` exactly as it already ships.
  Stream<int> watchUnreadCount(String uid) {
    return _notifications(uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> markRead(String uid, String notificationId) {
    return _notifications(uid).doc(notificationId).update({'read': true});
  }

  /// One batched write instead of N round trips. Each individual update
  /// still touches only `read`, so it satisfies the same rule a single
  /// [markRead] does.
  Future<void> markAllRead(String uid, Iterable<String> notificationIds) {
    final ids = notificationIds.toList();
    if (ids.isEmpty) return Future.value();
    final batch = _firestore.batch();
    for (final id in ids) {
      batch.update(_notifications(uid).doc(id), {'read': true});
    }
    return batch.commit();
  }

  CollectionReference<Map<String, dynamic>> _notifications(String uid) {
    return _firestore.collection('users').doc(uid).collection('notifications');
  }
}

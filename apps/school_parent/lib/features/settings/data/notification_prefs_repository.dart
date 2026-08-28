import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Mirrors the NotificationPrefs shape in functions/src/index.ts — keep the
/// two in sync.
class NotificationPrefs {
  const NotificationPrefs({
    required this.tripStart,
    required this.tripPause,
    required this.tripEnd,
    required this.arrival,
    required this.minutesBefore,
  });

  final bool tripStart;
  final bool tripPause;
  final bool tripEnd;
  final bool arrival;
  // 0 disables the "N minutes before" heads-up alert.
  final int minutesBefore;

  static const defaults = NotificationPrefs(
    tripStart: true,
    tripPause: true,
    tripEnd: true,
    arrival: true,
    minutesBefore: 10,
  );

  factory NotificationPrefs.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    return NotificationPrefs(
      tripStart: data['tripStart'] != false,
      tripPause: data['tripPause'] != false,
      tripEnd: data['tripEnd'] != false,
      arrival: data['arrival'] != false,
      minutesBefore:
          (data['minutesBefore'] as num?)?.toInt() ?? defaults.minutesBefore,
    );
  }

  NotificationPrefs copyWith({
    bool? tripStart,
    bool? tripPause,
    bool? tripEnd,
    bool? arrival,
    int? minutesBefore,
  }) {
    return NotificationPrefs(
      tripStart: tripStart ?? this.tripStart,
      tripPause: tripPause ?? this.tripPause,
      tripEnd: tripEnd ?? this.tripEnd,
      arrival: arrival ?? this.arrival,
      minutesBefore: minutesBefore ?? this.minutesBefore,
    );
  }
}

class NotificationPrefsRepository {
  NotificationPrefsRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<NotificationPrefs> watch() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(NotificationPrefs.defaults);
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map(
          (snapshot) => NotificationPrefs.fromMap(
            snapshot.data()?['notificationPrefs'] as Map<String, dynamic>?,
          ),
        );
  }

  // A self-update, restricted by firestore.rules to just the
  // notificationPrefs field — writes to `users/{uid}` are otherwise
  // blocked. Direct write rather than a Cloud Function callable, matching
  // every other self-service write in this project (see registerParent):
  // this doesn't need the project on Firebase's paid Blaze plan.
  Future<void> update(NotificationPrefs prefs) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Future.value();

    return _firestore.collection('users').doc(uid).update({
      'notificationPrefs': {
        'tripStart': prefs.tripStart,
        'tripPause': prefs.tripPause,
        'tripEnd': prefs.tripEnd,
        'arrival': prefs.arrival,
        'minutesBefore': prefs.minutesBefore,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

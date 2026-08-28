// Reuses the same Firebase project (sharlok-ef2b4) as the other apps —
// Auth/Firestore work at the project level via apiKey+projectId, so sharing
// the web/android app registration here is functionally fine. Only worth
// giving this app its own FlutterFire-registered app entry later if you
// want separate Analytics/Crashlytics attribution for it specifically.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBWo3_5iyJrKcLFeNNwrL9gmusGeNKCVOw',
    appId: '1:685828487805:web:77854252298e4f206d0f14',
    messagingSenderId: '685828487805',
    projectId: 'sharlok-ef2b4',
    authDomain: 'sharlok-ef2b4.firebaseapp.com',
    databaseURL: 'https://sharlok-ef2b4-default-rtdb.firebaseio.com',
    storageBucket: 'sharlok-ef2b4.firebasestorage.app',
    measurementId: 'G-P0GR31LWDG',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD_S_OLewM8xF-Crn0W7V2cJJhiieagBIc',
    appId: '1:685828487805:android:227d4e0dd14af66c6d0f14',
    messagingSenderId: '685828487805',
    projectId: 'sharlok-ef2b4',
    databaseURL: 'https://sharlok-ef2b4-default-rtdb.firebaseio.com',
    storageBucket: 'sharlok-ef2b4.firebasestorage.app',
  );
}

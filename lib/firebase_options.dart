// firebase_options.dart — configuração Firebase para Web + Android + iOS
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  // ── Web ────────────────────────────────────────────────────────────────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB0qklzhpRDAuppvieY3dy8hiPLQDucF18',
    authDomain: 'medcases-pro.firebaseapp.com',
    projectId: 'medcases-pro',
    storageBucket: 'medcases-pro.firebasestorage.app',
    messagingSenderId: '1076800980330',
    appId: '1:1076800980330:web:40fe63bbd4db4fcb711113',
  );

  // ── Android ────────────────────────────────────────────────────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDPY3OH6KMoPdEp85i_y69_bKqc3wK2340',
    authDomain: 'medcases-pro.firebaseapp.com',
    projectId: 'medcases-pro',
    storageBucket: 'medcases-pro.firebasestorage.app',
    messagingSenderId: '1076800980330',
    appId: '1:1076800980330:android:458a6b1f05871619711113',
  );

  // ── iOS ─────────────────────────────────────────────────────────────────────
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDPY3OH6KMoPdEp85i_y69_bKqc3wK2340',
    authDomain: 'medcases-pro.firebaseapp.com',
    projectId: 'medcases-pro',
    storageBucket: 'medcases-pro.firebasestorage.app',
    messagingSenderId: '1076800980330',
    appId: '1:1076800980330:ios:458a6b1f05871619711113',
    iosBundleId: 'com.medcasespro.flutterApp',
  );
}

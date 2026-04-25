// Firebase Options for bizpos-clone project
// Generated manually

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        return android;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAQ4ZosJ8RdK0K5kQ7IRQFyb2DjaK3iwM4',
    appId: '1:259223330355:web:1941d2534f55a267dbcd46',
    messagingSenderId: '259223330355',
    projectId: 'bizpos-clone',
    authDomain: 'bizpos-clone.firebaseapp.com',
    storageBucket: 'bizpos-clone.firebasestorage.app',
    measurementId: 'G-GMPGJ29B88',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAQ4ZosJ8RdK0K5kQ7IRQFyb2DjaK3iwM4',
    appId: '1:259223330355:android:1941d2534f55a267dbcd46',
    messagingSenderId: '259223330355',
    projectId: 'bizpos-clone',
    storageBucket: 'bizpos-clone.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAQ4ZosJ8RdK0K5kQ7IRQFyb2DjaK3iwM4',
    appId: '1:259223330355:ios:placeholder',
    messagingSenderId: '259223330355',
    projectId: 'bizpos-clone',
    storageBucket: 'bizpos-clone.firebasestorage.app',
  );
}

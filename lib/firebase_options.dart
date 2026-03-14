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
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDQx1VgIikpaRImOvYRneud0RpHqmk6NVg',
    appId: '1:1040951039356:web:f43db311c01122046c40f9',
    messagingSenderId: '1040951039356',
    projectId: 'agridrone-guardian',
    authDomain: 'agridrone-guardian.firebaseapp.com',
    storageBucket: 'agridrone-guardian.firebasestorage.app',
    measurementId: 'G-KT3YZ2Z7VF',
    databaseURL: 'https://agridrone-guardian-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  // Placeholders for other platforms if needed, but web is primary
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDQx1VgIikpaRImOvYRneud0RpHqmk6NVg',
    appId: 'placeholder',
    messagingSenderId: '1040951039356',
    projectId: 'agridrone-guardian',
    storageBucket: 'agridrone-guardian.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDQx1VgIikpaRImOvYRneud0RpHqmk6NVg',
    appId: 'placeholder',
    messagingSenderId: '1040951039356',
    projectId: 'agridrone-guardian',
    storageBucket: 'agridrone-guardian.firebasestorage.app',
    iosBundleId: 'com.example.agridrone_guardian',
  );
}

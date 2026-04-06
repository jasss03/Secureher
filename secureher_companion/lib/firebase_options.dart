// File generated for local development to mirror the SecureHer Firebase project.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

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
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAH4ioId-gjIZXkDU3aNmaDjeDclwXY9p8',
    appId: '1:346182049858:web:aeab975472fe73dd380ddb',
    messagingSenderId: '346182049858',
    projectId: 'her-b03d7',
    authDomain: 'her-b03d7.firebaseapp.com',
    storageBucket: 'her-b03d7.firebasestorage.app',
    measurementId: 'G-40C7GMZZ5L',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAH4ioId-gjIZXkDU3aNmaDjeDclwXY9p8',
    appId: '1:346182049858:android:5d2d0745e6fb0793380ddb',
    messagingSenderId: '346182049858',
    projectId: 'her-b03d7',
    storageBucket: 'her-b03d7.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAH4ioId-gjIZXkDU3aNmaDjeDclwXY9p8',
    appId: '1:346182049858:ios:061220caaf35f882380ddb',
    messagingSenderId: '346182049858',
    projectId: 'her-b03d7',
    storageBucket: 'her-b03d7.firebasestorage.app',
    androidClientId:
        '346182049858-8nd2i9a832inhpsue88sict8pv4tup5m.apps.googleusercontent.com',
    iosClientId:
        '346182049858-0s4qte377d40o4ga16f27m4jel3vrnrq.apps.googleusercontent.com',
    iosBundleId: 'com.secureher.secureherCompanion',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAQZxD9dJ_wFngIkcnDsamPRgjzaEmb8Ek',
    appId: '1:346182049858:ios:061220caaf35f882380ddb',
    messagingSenderId: '346182049858',
    projectId: 'her-b03d7',
    storageBucket: 'her-b03d7.firebasestorage.app',
    androidClientId:
        '346182049858-8nd2i9a832inhpsue88sict8pv4tup5m.apps.googleusercontent.com',
    iosClientId:
        '346182049858-0s4qte377d40o4ga16f27m4jel3vrnrq.apps.googleusercontent.com',
    iosBundleId: 'com.secureher.secureherCompanion',
  );
}

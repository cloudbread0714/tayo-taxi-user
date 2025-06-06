// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
      case TargetPlatform.windows:
        return windows;
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
    apiKey: 'AIzaSyCWM81XBJn0kgNt8rCIBjO8ggwqvZe36xQ',
    appId: '1:746335666026:web:e1d8c70195df1247ccef13',
    messagingSenderId: '746335666026',
    projectId: 'tayotaxi-bc7b6',
    authDomain: 'tayotaxi-bc7b6.firebaseapp.com',
    storageBucket: 'tayotaxi-bc7b6.firebasestorage.app',
    measurementId: 'G-DGMBX7MHY3',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCoA7jcNk9RovOJGjWDh9CQbh-YFNALdm8',
    appId: '1:746335666026:android:e2f6cfa93752cc3dccef13',
    messagingSenderId: '746335666026',
    projectId: 'tayotaxi-bc7b6',
    storageBucket: 'tayotaxi-bc7b6.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCNaIMsXC-DEui4eW3eSM9AcRFbyg_LccQ',
    appId: '1:746335666026:ios:8d53c5f284fca273ccef13',
    messagingSenderId: '746335666026',
    projectId: 'tayotaxi-bc7b6',
    storageBucket: 'tayotaxi-bc7b6.firebasestorage.app',
    iosBundleId: 'com.example.appTayoTaxi',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCNaIMsXC-DEui4eW3eSM9AcRFbyg_LccQ',
    appId: '1:746335666026:ios:8d53c5f284fca273ccef13',
    messagingSenderId: '746335666026',
    projectId: 'tayotaxi-bc7b6',
    storageBucket: 'tayotaxi-bc7b6.firebasestorage.app',
    iosBundleId: 'com.example.appTayoTaxi',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCWM81XBJn0kgNt8rCIBjO8ggwqvZe36xQ',
    appId: '1:746335666026:web:07e3c2ce4b43e074ccef13',
    messagingSenderId: '746335666026',
    projectId: 'tayotaxi-bc7b6',
    authDomain: 'tayotaxi-bc7b6.firebaseapp.com',
    storageBucket: 'tayotaxi-bc7b6.firebasestorage.app',
    measurementId: 'G-N4WYK9N8SH',
  );
}

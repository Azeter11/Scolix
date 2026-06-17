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
    apiKey: 'AIzaSyDNjjSuLHymXaW2KSI2Lp7VxI8pReQZhV8',
    appId: '1:1077454726059:web:d0c8fed355a6897e6068ee',
    messagingSenderId: '1077454726059',
    projectId: 'scolix-ea8c1',
    authDomain: 'scolix-ea8c1.firebaseapp.com',
    storageBucket: 'scolix-ea8c1.firebasestorage.app',
    measurementId: 'G-8QDJTX6PXW',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCQNUaamYcLM6XfuFy-UKqu7FpFFo50Pyg',
    appId: '1:1077454726059:android:8e8111ffda635c1c6068ee',
    messagingSenderId: '1077454726059',
    projectId: 'scolix-ea8c1',
    storageBucket: 'scolix-ea8c1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDyiP9fH0KBK6ft5tR5voUbSxxY5tbCtaY',
    appId: '1:1077454726059:ios:36b895bc5fbf18636068ee',
    messagingSenderId: '1077454726059',
    projectId: 'scolix-ea8c1',
    storageBucket: 'scolix-ea8c1.firebasestorage.app',
    androidClientId: '1077454726059-nlqcst6nvfcf6bpvfnlou4r8kprs69kv.apps.googleusercontent.com',
    iosClientId: '1077454726059-p6ccgse8epcoried5dfd6ou4r7f8kq86.apps.googleusercontent.com',
    iosBundleId: 'com.example.scolixClean',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDyiP9fH0KBK6ft5tR5voUbSxxY5tbCtaY',
    appId: '1:1077454726059:ios:36b895bc5fbf18636068ee',
    messagingSenderId: '1077454726059',
    projectId: 'scolix-ea8c1',
    storageBucket: 'scolix-ea8c1.firebasestorage.app',
    androidClientId: '1077454726059-nlqcst6nvfcf6bpvfnlou4r8kprs69kv.apps.googleusercontent.com',
    iosClientId: '1077454726059-p6ccgse8epcoried5dfd6ou4r7f8kq86.apps.googleusercontent.com',
    iosBundleId: 'com.example.scolixClean',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDNjjSuLHymXaW2KSI2Lp7VxI8pReQZhV8',
    appId: '1:1077454726059:web:c86f33de309d6b416068ee',
    messagingSenderId: '1077454726059',
    projectId: 'scolix-ea8c1',
    authDomain: 'scolix-ea8c1.firebaseapp.com',
    storageBucket: 'scolix-ea8c1.firebasestorage.app',
    measurementId: 'G-VSWWTBQ3N9',
  );
}

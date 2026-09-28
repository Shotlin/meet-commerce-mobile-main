import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions are only configured for Android and iOS.',
        );
    }
  }

  // Real FreshCuts Firebase project (freshcuts-slin), registered 2026-09-28
  // for package com.freshcuts.app — the same project already used by the
  // vendor app and already wired into the backend's Admin SDK credentials.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCaKRF8ulk2sW5my6vJ-KmKZxPHFeuCh_s',
    appId: '1:493517915093:android:b5fd538abecfbdda5af35c',
    messagingSenderId: '493517915093',
    projectId: 'freshcuts-slin',
    storageBucket: 'freshcuts-slin.firebasestorage.app',
  );

  // iOS is not yet registered in Firebase — still deliberately dummy so
  // Firebase.initializeApp() fails non-fatally on iOS rather than silently
  // misreporting under the Android app's identity. Register com.bakaloo.india
  // in the Firebase console and fill this in when iOS push is needed.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'dummy-not-configured',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'meet-commerce-dev-unconfigured',
    storageBucket: 'meet-commerce-dev-unconfigured.firebasestorage.app',
    iosBundleId: 'com.bakaloo.india',
  );
}

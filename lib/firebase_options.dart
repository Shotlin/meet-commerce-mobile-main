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

  // Placeholder/dummy values — deliberately NOT Bakaloo's real Firebase
  // project. meet-commerce has no Firebase project of its own yet; the app
  // already treats Firebase.initializeApp() failure as non-fatal (see
  // main.dart's "dummy keys?" comment), so this intentionally fails to
  // initialize rather than silently reporting meet-commerce dev/test
  // analytics and crash data into a real, separate business's live project.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'dummy-not-configured',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'meet-commerce-dev-unconfigured',
    storageBucket: 'meet-commerce-dev-unconfigured.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'dummy-not-configured',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'meet-commerce-dev-unconfigured',
    storageBucket: 'meet-commerce-dev-unconfigured.firebasestorage.app',
    iosBundleId: 'com.bakaloo.india',
  );
}

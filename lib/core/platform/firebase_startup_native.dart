import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:bakaloo_flutter_app/firebase_options.dart';

Future<void> _ensureFirebaseInitialized() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (error) {
    if (error.code != 'duplicate-app') rethrow;
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await _ensureFirebaseInitialized();
  } catch (error) {
    debugPrint('Firebase background init failed (dummy keys?): $error');
  }
}

Future<void> initializeFirebaseServices() async {
  try {
    // iOS may have auto-configured the native Firebase app before Dart starts;
    // duplicate-app is therefore treated as successful initialization.
    await _ensureFirebaseInitialized();
    debugPrint('Firebase initialized');

    if (!kDebugMode) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError =
          (Object error, StackTrace stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }

    FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler,
    );
  } catch (error) {
    // Firebase is optional for startup; API-backed commerce remains usable if
    // native configuration is absent or invalid in a development build.
    debugPrint('Firebase init failed (dummy keys?): $error');
  }
}

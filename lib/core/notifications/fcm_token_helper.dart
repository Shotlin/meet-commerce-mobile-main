import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// iOS assigns the device its APNs token asynchronously after notification
/// permission is granted. Calling [FirebaseMessaging.getToken] before that
/// resolves throws `firebase_messaging/apns-token-not-set` — reproduced
/// directly against a real login on the iOS Simulator, and the same race
/// applies on a real device. There is no public "wait for APNs token" API
/// in FlutterFire, so the standard workaround is a short poll before asking
/// for the FCM token. Android has no APNs concept and returns its token
/// immediately regardless.
Future<String?> getFcmTokenAwaitingApns(FirebaseMessaging messaging) async {
  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    var apnsToken = await messaging.getAPNSToken();
    var attempts = 0;
    while (apnsToken == null && attempts < 10) {
      await Future.delayed(const Duration(milliseconds: 500));
      apnsToken = await messaging.getAPNSToken();
      attempts++;
    }
    if (apnsToken == null) return null;
  }
  return messaging.getToken();
}

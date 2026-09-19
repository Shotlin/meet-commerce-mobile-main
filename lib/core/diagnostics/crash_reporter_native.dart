import 'package:firebase_crashlytics/firebase_crashlytics.dart';

Future<void> reportError(
  Object error,
  StackTrace stack, {
  String? reason,
  bool fatal = false,
}) {
  return FirebaseCrashlytics.instance.recordError(
    error,
    stack,
    reason: reason,
    fatal: fatal,
  );
}

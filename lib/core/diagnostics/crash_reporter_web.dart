/// Browser builds do not initialize Firebase Crashlytics until a real Web
/// Firebase configuration is supplied. Keep diagnostics non-fatal meanwhile.
Future<void> reportError(
  Object error,
  StackTrace stack, {
  String? reason,
  bool fatal = false,
}) async {}

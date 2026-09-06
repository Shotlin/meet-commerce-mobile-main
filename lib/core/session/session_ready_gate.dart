import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Signals when the app's one-time startup auth check (splash screen —
/// see `SplashController.handleStartup`) has finished deciding whether the
/// persisted session is valid.
///
/// FCM notification taps can fire a router navigation to a protected route
/// (e.g. `/orders/123`) within milliseconds of a cold start — well before
/// the splash screen has read the stored tokens and restored `AuthState`.
/// Without this gate, that navigation runs while `authStateProvider` still
/// holds its default `AuthUnauthenticated()` value, so the router's guard
/// bounces an already-logged-in user to the login screen. Anything that
/// navigates in response to a notification should `await ready` first.
class SessionReadyGate {
  final Completer<void> _completer = Completer<void>();

  Future<void> get ready => _completer.future;

  void markReady() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }
}

final sessionReadyGateProvider = Provider<SessionReadyGate>((Ref ref) {
  return SessionReadyGate();
});

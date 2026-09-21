import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as location_pkg;

/// Prompts the customer to turn device location ON using Android's native
/// Google Play Services "Location Accuracy" resolution dialog — the same
/// in-app "Turn on" dialog Zomato/Blinkit use — instead of bouncing them
/// out to the OS Settings app and back.
///
/// geolocator (used everywhere else in this app for permission/position
/// APIs) has no equivalent of this: it can only detect that the service is
/// off and open Settings via `Geolocator.openLocationSettings()`. Only the
/// `location` package's `requestService()` drives Play Services'
/// `SettingsClient`, which is what actually renders that native dialog and
/// resolves it without leaving the app. It's used here purely for that one
/// call — everything else location-related in this app still goes through
/// geolocator.
///
/// Returns true once the service is confirmed on (whether it already was,
/// or the customer just turned it on from the dialog); false if they
/// dismissed it ("No, thanks") or it's still off for any other reason.
///
/// iOS has no equivalent API — Apple doesn't expose a way to resolve this
/// in-app — so there this falls back to opening Settings directly, same as
/// before.
Future<bool> requestEnableLocationService() async {
  if (!Platform.isAndroid) {
    await Geolocator.openLocationSettings();
    return _waitForServiceEnabled();
  }

  try {
    return await location_pkg.Location().requestService();
  } catch (_) {
    // Play Services unavailable/out of date, or the resolution flow failed
    // for some other reason — Settings is still a working fallback rather
    // than leaving the customer stuck with no way forward at all.
    await Geolocator.openLocationSettings();
    return _waitForServiceEnabled();
  }
}

/// Waits for the OS to actually report location as enabled, instead of
/// checking `Geolocator.isLocationServiceEnabled()` immediately.
///
/// Root cause of the iOS bug this fixes: `Geolocator.openLocationSettings()`
/// only launches the Settings app — its Future completes the instant that
/// launch succeeds, which is a fraction of a second later, NOT when the
/// customer has actually found Location Services and switched it on and
/// come back. Checking the service state right after that await was
/// therefore always checking before the customer had done anything, so it
/// read "still off" and reported failure on effectively every attempt —
/// regardless of whether they went on to enable it moments later.
///
/// `Geolocator.getServiceStatusStream()` alone isn't a fix for this either
/// — traced to its native iOS implementation
/// (LocationServiceStreamHandler.m in geolocator_apple), that stream is
/// driven entirely by CLLocationManager's `didChangeAuthorizationStatus`
/// delegate callback. That fires on a *permission* change, not reliably on
/// the device-wide Location Services switch the customer just flipped in
/// Settings — so waiting on it alone could sit doing nothing for the full
/// 3-minute timeout even though the customer already turned location on
/// and came straight back. Racing it against [waitForAppResume] closes
/// that gap: the instant the customer returns to the app (regardless of
/// whether the stream ever emits anything), this falls through to a
/// direct, authoritative `isLocationServiceEnabled()` poll instead of
/// waiting out the clock.
Future<bool> _waitForServiceEnabled() async {
  if (await Geolocator.isLocationServiceEnabled()) {
    return true;
  }
  try {
    await Future.any<void>(<Future<void>>[
      Geolocator.getServiceStatusStream()
          .firstWhere((status) => status == ServiceStatus.enabled),
      waitForAppResume(),
    ]);
  } catch (_) {
    // Ignore — the direct poll below is authoritative either way.
  }
  return Geolocator.isLocationServiceEnabled();
}

/// Opens the app's own Settings page so the customer can flip the location
/// *permission* toggle back on — distinct from `requestEnableLocationService`
/// above, which opens the device-wide Location Services page instead.
///
/// Needed once `Geolocator.checkPermission()`/`requestPermission()` comes
/// back `LocationPermission.deniedForever`: on iOS a single "Don't Allow" is
/// immediately permanent (unlike Android's two-step denied -> denied
/// forever), and after that Apple will never show its own system permission
/// dialog again for this install. Re-calling `requestPermission()` at that
/// point just resolves instantly with the same deniedForever result — this
/// app Settings deep link is the only way back.
Future<void> openLocationPermissionSettings() {
  return Geolocator.openAppSettings();
}

/// Completes the first time this app returns to the foreground after being
/// backgrounded — the reliable signal that a customer sent to Settings
/// (either for location services or app permission) has come back, so
/// whatever they changed there can be re-checked immediately instead of
/// only on their next explicit tap. Falls back to completing after
/// [timeout] regardless, so a customer who never comes back (force-quits,
/// switches apps for good) doesn't leave a caller awaiting this forever.
Future<void> waitForAppResume({
  Duration timeout = const Duration(minutes: 3),
}) {
  final completer = Completer<void>();
  late final _AppResumeObserver observer;
  observer = _AppResumeObserver(() {
    if (!completer.isCompleted) {
      completer.complete();
    }
  });
  WidgetsBinding.instance.addObserver(observer);

  return completer.future
      .timeout(timeout, onTimeout: () {})
      .whenComplete(() => WidgetsBinding.instance.removeObserver(observer));
}

class _AppResumeObserver with WidgetsBindingObserver {
  _AppResumeObserver(this._onResumed);

  final VoidCallback _onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onResumed();
    }
  }
}

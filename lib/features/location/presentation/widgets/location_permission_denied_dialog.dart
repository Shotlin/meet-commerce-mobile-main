import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:bakaloo_flutter_app/core/utils/location_service_resolver.dart';

/// Shown when `Geolocator.checkPermission()`/`requestPermission()` comes back
/// `LocationPermission.deniedForever` — the system permission dialog itself
/// will never appear again for this install (iOS makes denial permanent
/// after a single "Don't Allow"; Android after "Deny" is picked twice), so a
/// plain "permission required" toast/snackbar is a dead end with no way to
/// actually recover. This gives the customer a direct path to the one place
/// that still works: the app's own Settings page.
class LocationPermissionDeniedDialog {
  LocationPermissionDeniedDialog._();

  /// Returns true if the customer tapped "Open Settings" (regardless of
  /// what they actually changed there); false for "Not now"/dismissed.
  static Future<bool> show(BuildContext context) async {
    final openedSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location permission blocked'),
        content: const Text(
          'Bakaloo needs your location to autofill your delivery address. '
          'Please enable it from Settings.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              unawaited(openLocationPermissionSettings());
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    return openedSettings ?? false;
  }
}

/// Runs geolocator's normal check/request flow, and if that comes back
/// permanently denied, offers [LocationPermissionDeniedDialog] — if the
/// customer takes it to Settings and grants permission there, this picks
/// that up the moment they return to the app instead of requiring a second
/// manual tap of whatever button got them here.
///
/// Returns the resulting permission: `always`/`whileInUse` once granted
/// (immediately, or after the Settings round-trip); otherwise whatever
/// `denied`/`deniedForever` state it's still stuck in.
Future<LocationPermission> resolveLocationPermission(
  BuildContext context,
) async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission != LocationPermission.deniedForever || !context.mounted) {
    return permission;
  }

  final openedSettings = await LocationPermissionDeniedDialog.show(context);
  if (!openedSettings) {
    return permission;
  }

  // The customer may have granted permission in Settings and come straight
  // back — waitForAppResume catches that return reliably instead of
  // leaving them to notice nothing happened and tap the button again.
  await waitForAppResume();
  return Geolocator.checkPermission();
}

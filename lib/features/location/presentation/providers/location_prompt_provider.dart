import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:bakaloo_flutter_app/core/maps/geo_point.dart';
import 'package:bakaloo_flutter_app/core/maps/ola/ola_maps_service.dart';
import 'package:bakaloo_flutter_app/core/utils/resilient_location.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/repositories/address_repository.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';
import 'package:bakaloo_flutter_app/features/location/presentation/providers/non_serviceable_location_provider.dart';

/// Returns true if the location-enable prompt should be shown right now:
/// the user is authenticated AND has no saved address at all.
///
/// A saved address — complete or not — is handled entirely by
/// home_screen.dart's `_maybeShowLocationPrompt` without this provider:
/// once there's at least one address, whether to nudge the customer again
/// depends on whether THAT address still needs a house/building number,
/// never on the device's current permission/service state.
///
/// Previously this also returned true whenever permission was denied or
/// the location service was off, even for a customer who already had a
/// complete saved address — so toggling location off and back on (or any
/// of the several things that made the OS re-report service status, which
/// happens on plenty of ordinary refreshes/resumes) brought the "enable
/// location" sheet back every time, regardless of the fact that they had
/// nothing left to do. Reported bug: "I already filled my address... I
/// refresh the page... same location popup comes again." Having any
/// saved address at all now fully satisfies this check.
final locationPromptShouldShowProvider = FutureProvider<bool>((ref) async {
  final authState = ref.watch(authStateProvider);
  if (authState is! AuthAuthenticated) return false;

  final addresses = await ref.watch(addressProvider.future);
  return addresses.isEmpty;
});

/// Result of attempting to detect and save the user's location.
enum LocationAutoDetectResult {
  success,
  permissionDenied,
  permissionPermanentlyDenied,
  locationServiceDisabled,
  geocodingFailed,
  // The detected pincode resolved fine, but Bakaloo doesn't deliver there —
  // no shop has it in its serviceable_pincodes/radius. Distinct from
  // saveFailed so the sheet can show "we don't deliver here" instead of a
  // generic "could not detect location" that implies a retry might help.
  notServiceable,
  saveFailed,
  unknown,
}

// Exact wording the backend returns (addresses.service.js create/update)
// when its own hard serviceability gate rejects the address — matched here
// as a defense-in-depth fallback for the rarer case where validatePincode
// (checked below, pincode-list only) says available but the actual
// create/update call still gets blocked by the radius-based check.
const _kNotServiceableMessage = 'Delivery is not available at this address yet.';

/// Requests permission, gets a position, reverse-geocodes it, and saves it
/// as the user's default address. Used both by the sheet's own "Enable"
/// button and its auto-trigger on open — either way there's a visible
/// spinner, so a multi-second wait is fine.
///
/// Prefers the OS's cached last-known position (near-instant, no GPS
/// engagement, and accurate enough for a delivery address) before paying
/// the cost of a fresh fix, which can easily take well over 10s on a cold
/// start (indoors, weak signal) — that used to surface as a flat "could
/// not detect location" no matter how long the customer waited. Only
/// requests a fresh fix when there's no cached position at all.
Future<LocationAutoDetectResult> detectAndSaveCurrentLocation(
  WidgetRef ref,
) async {
  try {
    // 1. Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationAutoDetectResult.locationServiceDisabled;
    }

    // 2. Request permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return LocationAutoDetectResult.permissionDenied;
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationAutoDetectResult.permissionPermanentlyDenied;
    }

    // 3. Get the current position — see getResilientCurrentPosition's own
    // doc comment for why this isn't a single flat getCurrentPosition()
    // call (right after the customer turns location on from Settings and
    // comes back, a single attempt regularly failed with "Could not
    // detect location" because the OS's location subsystem hasn't warmed
    // back up yet).
    Position position;
    try {
      position = await getResilientCurrentPosition();
    } catch (err, stack) {
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          err,
          stack,
          reason: 'detectAndSaveCurrentLocation: getResilientCurrentPosition '
              'exhausted every fallback with no position to fall back on',
          fatal: false,
        ),
      );
      return LocationAutoDetectResult.unknown;
    }

    return _geocodeAndSave(ref, position);
  } catch (err, stack) {
    unawaited(
      FirebaseCrashlytics.instance.recordError(
        err,
        stack,
        reason: 'detectAndSaveCurrentLocation: unexpected failure',
        fatal: false,
      ),
    );
    return LocationAutoDetectResult.unknown;
  }
}

/// Reverse-geocodes [position] and saves it as the user's default address.
/// Shared tail end of both detect paths above. Goes through Ola Maps (same
/// provider the map picker uses) rather than the phone's own OS geocoder —
/// Ola's response also carries a landmark, which the OS geocoder never gave
/// us at all.
Future<LocationAutoDetectResult> _geocodeAndSave(
  WidgetRef ref,
  Position position,
) async {
  final reverse = await ref.read(olaMapsServiceProvider).reverseGeocode(
        GeoPoint(lat: position.latitude, lng: position.longitude),
      );

  final city = reverse?.city ?? '';
  final state = reverse?.state ?? '';
  final pincode = reverse?.pincode ?? '';
  final road = reverse?.addressLine1 ?? '';
  final displayName = reverse?.displayName ?? '';

  if (reverse == null ||
      (city.isEmpty &&
          state.isEmpty &&
          pincode.isEmpty &&
          road.isEmpty &&
          displayName.isEmpty)) {
    unawaited(
      FirebaseCrashlytics.instance.recordError(
        StateError('Ola reverseGeocode returned nothing usable'),
        StackTrace.current,
        reason: '_geocodeAndSave: reverse geocoding failed',
        fatal: false,
      ),
    );
    return LocationAutoDetectResult.geocodingFailed;
  }

  // A bare city name ("Shimulpur") reads as broken, not as an address — Ola's
  // full formatted address (still specific to the pin, just without a named
  // road) is what belongs here when there's no distinct road/route
  // component; city/state are the very last resort, only when Ola gave
  // nothing descriptive back at all.
  final addressLine1 = road.isNotEmpty
      ? road
      : (displayName.isNotEmpty
          ? displayName
          : (city.isNotEmpty
              ? city
              : (state.isNotEmpty ? state : 'My Location')));

  // addressLine2 is deliberately left null here, never filled with Ola's
  // landmark/sub-locality — home_screen.dart's _maybeShowLocationPrompt (and
  // the "complete your address" banner check) both treat a non-empty
  // addressLine2 as proof the customer has already supplied a house/floor
  // number, since that's the only path that ever writes it today
  // (_composeSecondaryAddress in add_edit_address_screen.dart always puts
  // House No. first). Landmark is instead fetched live when the completion
  // screen opens — see _seedFromInitialAddress's forceCompletion branch —
  // so this silent auto-save can't accidentally mark a house-number-less
  // address as "done."
  const addressLine2 = null;

  // Same availability check the manual "Add address" form already runs on
  // every pincode the customer types — reused here so "Use my current
  // location" rejects an unserviceable area just as reliably instead of
  // silently saving an address Bakaloo can never actually deliver to.
  // Skipped when geocoding didn't return a pincode at all (some rural
  // areas): nothing to validate, so this falls through to the old
  // behavior rather than blocking on missing data. A validation-call
  // failure (e.g. flaky network) also falls through rather than blocking —
  // the create/update call below still enforces serviceability server-side
  // regardless, via the _kNotServiceableMessage check.
  if (pincode.isNotEmpty) {
    final validation =
        await ref.read(validatePincodeUseCaseProvider).call(pincode);
    final isServiceable = validation.fold((_) => true, (r) => r.available);
    if (!isServiceable) {
      // Nothing gets saved (the backend would reject it anyway — see
      // ADDRESS_NOT_SERVICEABLE) so this flag is the only trace that
      // detection happened, for the cart's benefit later — see
      // non_serviceable_location_provider.dart.
      unawaited(
        ref.read(nonServiceableLocationProvider.notifier).markDetected(),
      );
      return LocationAutoDetectResult.notServiceable;
    }
  }

  // Save as default address
  final params = AddressUpsertParams(
    label: 'Home',
    addressLine1: addressLine1,
    addressLine2: addressLine2,
    city: city,
    state: state,
    pincode: pincode,
    latitude: position.latitude,
    longitude: position.longitude,
    isDefault: true,
  );

  // Root cause of a real reported bug: this used to unconditionally call
  // createAddress, even when the customer already had a default address
  // on file. home_screen.dart's _maybeShowLocationPrompt only ever shows
  // this sheet at all when there's currently no address — but the device's
  // location-service-status stream can re-fire (Android re-reports it for
  // reasons unrelated to anything the customer did) and re-trigger the
  // whole detect flow AFTER the customer already completed their address
  // through a different call of this same function. Always creating meant
  // that second call added a SECOND "Home" address with no house number
  // and made IT the new default — so the app correctly (from its own
  // logic's point of view) decided there was an incomplete address again
  // and sent the customer straight back into the completion screen, in a
  // loop, no matter how many times they filled it in. Reported: "I fill my
  // address... then homepage shows the same address field again... I
  // press Enable, that repeats the address details page."
  //
  // Updating the existing default in place — when there is one — instead
  // of always inserting a new row closes that loop at its source: a
  // second detect can only ever refresh the SAME row's coordinates, never
  // spawn a competing one. Only reached with an existing address at all
  // when it's the exact "no house number yet" address this whole flow
  // exists to fill in (see the class-level doc comment on
  // locationPromptShouldShowProvider) — a customer with a genuinely
  // complete address is never routed through this sheet in the first
  // place, so this never risks overwriting real, already-entered details.
  final existingAddresses =
      ref.read(addressProvider).asData?.value ?? const [];
  final existingDefaultId = existingAddresses.isEmpty
      ? null
      : existingAddresses
          .firstWhere(
            (a) => a.isDefault,
            orElse: () => existingAddresses.first,
          )
          .id;

  final result = existingDefaultId != null
      ? await ref
          .read(addressProvider.notifier)
          .updateAddress(existingDefaultId, params)
      : await ref.read(addressProvider.notifier).createAddress(params);

  if (!result.isSuccess) {
    if (result.failure?.message == _kNotServiceableMessage) {
      unawaited(
        ref.read(nonServiceableLocationProvider.notifier).markDetected(),
      );
      return LocationAutoDetectResult.notServiceable;
    }
    unawaited(
      FirebaseCrashlytics.instance.recordError(
        StateError(result.failure?.message ?? 'unknown'),
        StackTrace.current,
        reason: '_geocodeAndSave: ${existingDefaultId != null ? 'update' : 'create'}Address failed',
        fatal: false,
      ),
    );
    return LocationAutoDetectResult.saveFailed;
  }

  // Refresh addresses so cart/checkout picks up the new default
  ref.invalidate(addressProvider);

  return LocationAutoDetectResult.success;
}

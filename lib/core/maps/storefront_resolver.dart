import 'package:bakaloo_flutter_app/core/utils/pincode.dart';

/// Body of `POST /storefront/resolve-location`.
///
/// A shop configured "pincode only" is matched by PIN alone (never by
/// distance), so the PIN must be sent whenever it is known. A missing or
/// malformed PIN is omitted rather than sent as garbage; the backend then
/// falls back to coordinate (radius) matching.
Map<String, dynamic> buildResolveLocationPayload({
  required double lat,
  required double lng,
  String? pincode,
}) {
  final String? pin = normalizePincode(pincode);
  return <String, dynamic>{
    'lat': lat,
    'lng': lng,
    if (pin != null) 'pincode': pin,
  };
}

/// Performs one resolve call and returns the decoded `data` object.
typedef ResolveLocationCall = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> payload,
);

class StorefrontResolution {
  const StorefrontResolution({
    required this.serviceable,
    required this.data,
    this.pincode,
  });

  final bool serviceable;

  /// The `data` object of the response that decided the outcome.
  final Map<String, dynamic> data;

  /// The PIN that produced the match (or the first PIN tried when none did).
  final String? pincode;
}

/// Resolves a customer's storefront trying every distinct PIN [candidates]
/// (best source first) until one is served; with no PIN at all a single
/// coordinates-only call is made.
///
/// Different geocoders can return different PINs for the same spot; stopping
/// at the first one that the shop list serves is what lets "my PIN is in the
/// shop's serviceable list" actually resolve, regardless of which geocoder
/// happened to report it. At most one call per distinct PIN is made.
Future<StorefrontResolution> resolveStorefront({
  required double lat,
  required double lng,
  required Iterable<String?> candidates,
  required ResolveLocationCall call,
}) async {
  final List<String> pins = dedupePincodes(candidates);
  final List<String?> attempts = pins.isEmpty ? <String?>[null] : pins;

  Map<String, dynamic> lastData = const <String, dynamic>{};
  for (final String? pin in attempts) {
    lastData = await call(
      buildResolveLocationPayload(lat: lat, lng: lng, pincode: pin),
    );
    if (lastData['serviceable'] == true) {
      return StorefrontResolution(
        serviceable: true,
        data: lastData,
        pincode: pin,
      );
    }
  }
  return StorefrontResolution(
    serviceable: false,
    data: lastData,
    pincode: pins.isEmpty ? null : pins.first,
  );
}

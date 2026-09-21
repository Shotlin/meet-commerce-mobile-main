import 'package:bakaloo_flutter_app/core/maps/geo_point.dart';

/// A valid Indian PIN: 6 digits, first digit 1-9 (same rule the backend
/// enforces on addresses and on a shop's serviceable pincodes).
final RegExp _indianPincodePattern = RegExp(r'^[1-9][0-9]{5}$');

/// Cleans a geocoder-provided postal code for serviceability matching:
/// strips all whitespace and returns it only if it is a valid 6-digit PIN.
/// Returns `null` for null/blank/malformed input so callers simply omit it.
String? normalizePincode(String? raw) {
  if (raw == null) return null;
  final String cleaned = raw.replaceAll(RegExp(r'\s+'), '');
  return _indianPincodePattern.hasMatch(cleaned) ? cleaned : null;
}

/// Request body for `POST /storefront/resolve-location`.
///
/// The PIN MUST be sent whenever it is known: a store configured "match by
/// pincode list only" is matched by the PIN alone (never by distance), so a
/// request that carries only lat/lng can never resolve such a store — even
/// when the customer is standing inside one of its serviceable PINs.
Map<String, dynamic> buildResolveLocationPayload(
  GeoPoint position, {
  String? pincode,
}) {
  final String? cleanPin = normalizePincode(pincode);
  return <String, dynamic>{
    'lat': position.lat,
    'lng': position.lng,
    if (cleanPin != null) 'pincode': cleanPin,
  };
}

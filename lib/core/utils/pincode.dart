/// Indian PIN-code helpers shared by every place a PIN enters the app
/// (device geocoder, Ola reverse-geocode, typed addresses, cached locations).
///
/// A PIN is compared as an EXACT string on the server against the PINs an admin
/// configured on a shop (`shops.serviceable_pincodes`), so a stray space, a
/// "700 001" spelling or a "700001, India" suffix from a geocoder is enough to
/// make a served PIN look unserviceable. Everything is normalised here first.
library;

final RegExp _separators = RegExp(r'[\s \-]+');
final RegExp _sixDigitPin = RegExp(r'(?<!\d)[1-9]\d{5}(?!\d)');

/// Returns the 6-digit PIN contained in [raw], or null when there is none.
///
/// Accepts `"700001"`, `" 700 001 "`, `"700-001"`, `"700001, India"` and
/// `"IN-700001"`. Rejects anything that is not a standalone 6-digit PIN
/// (`"70001"`, `"7000011"`, `"012345"`, empty).
String? normalizePincode(String? raw) {
  if (raw == null) {
    return null;
  }
  final String compact = raw.replaceAll(_separators, '');
  return _sixDigitPin.firstMatch(compact)?.group(0);
}

/// Normalises every entry, drops the ones that are not PINs and removes
/// duplicates while preserving the order of first appearance.
List<String> dedupePincodes(Iterable<String?> raws) {
  final Set<String> seen = <String>{};
  final List<String> pins = <String>[];
  for (final String? raw in raws) {
    final String? pin = normalizePincode(raw);
    if (pin != null && seen.add(pin)) {
      pins.add(pin);
    }
  }
  return List<String>.unmodifiable(pins);
}

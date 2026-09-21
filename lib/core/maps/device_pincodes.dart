import 'dart:async';

import 'package:geocoding/geocoding.dart';

import 'package:bakaloo_flutter_app/core/utils/pincode.dart';

/// PINs reported by the phone's own geocoder for a coordinate.
///
/// Reverse geocoders disagree (or omit `postal_code`) often enough that using
/// a single source made a customer standing inside a served PIN look
/// unserviceable. Every placemark is consulted and the result is normalised
/// and de-duplicated; failures and timeouts yield an empty list.
Future<List<DevicePlacemarkInfo>> reverseGeocodeOnDevice(
  double lat,
  double lng, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  try {
    final List<Placemark> placemarks =
        await placemarkFromCoordinates(lat, lng).timeout(timeout);
    return placemarks
        .map(
          (Placemark p) => DevicePlacemarkInfo(
            pincode: normalizePincode(p.postalCode),
            locality: p.locality?.trim(),
            administrativeArea: p.administrativeArea?.trim(),
          ),
        )
        .toList(growable: false);
  } catch (_) {
    return const <DevicePlacemarkInfo>[];
  }
}

class DevicePlacemarkInfo {
  const DevicePlacemarkInfo({
    this.pincode,
    this.locality,
    this.administrativeArea,
  });

  final String? pincode;
  final String? locality;
  final String? administrativeArea;
}

/// Distinct PINs across all [placemarks], in the geocoder's own order.
List<String> pincodesOf(Iterable<DevicePlacemarkInfo> placemarks) =>
    dedupePincodes(placemarks.map((DevicePlacemarkInfo p) => p.pincode));

import 'package:geocoding/geocoding.dart';

class DevicePlacemark {
  const DevicePlacemark({
    this.postalCode,
    this.locality,
    this.administrativeArea,
  });

  final String? postalCode;
  final String? locality;
  final String? administrativeArea;
}

Future<DevicePlacemark?> reverseGeocodeDeviceLocation(
  double latitude,
  double longitude,
) async {
  try {
    final placemarks = await placemarkFromCoordinates(latitude, longitude);
    if (placemarks.isEmpty) {
      return null;
    }
    final placemark = placemarks.first;
    return DevicePlacemark(
      postalCode: placemark.postalCode,
      locality: placemark.locality,
      administrativeArea: placemark.administrativeArea,
    );
  } catch (_) {
    return null;
  }
}

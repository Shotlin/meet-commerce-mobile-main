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

/// Browser geocoding uses the existing backend Ola proxy instead.
Future<DevicePlacemark?> reverseGeocodeDeviceLocation(
  double latitude,
  double longitude,
) async => null;

import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';

String resolveAddressLabel({
  required bool isLoggedIn,
  required List<AddressEntity>? addresses,
  String? guestAddressLine1,
  String? guestCity,
  String? guestPincode,
}) {
  if (!isLoggedIn) {
    final city = guestCity?.trim() ?? '';
    final pincode = guestPincode?.trim() ?? '';
    final line = guestAddressLine1?.trim() ?? '';
    if (city.isNotEmpty && pincode.isNotEmpty) return '$city, $pincode';
    if (line.isNotEmpty) return line;
    return 'Set your delivery location';
  }
  if (addresses == null || addresses.isEmpty) {
    return 'Add your delivery address for faster checkout';
  }
  final preferred = addresses.firstWhere(
    (a) => a.isDefault,
    orElse: () => addresses.first,
  );
  final city = preferred.city.trim();
  final pincode = preferred.pincode.trim();
  final line = preferred.addressLine1.trim();
  if (city.isNotEmpty && pincode.isNotEmpty) {
    return '$city, $pincode';
  }
  if (line.isNotEmpty) {
    return line;
  }
  return 'Set delivery address';
}

import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';

String resolveAddressLabel({
  required bool isLoggedIn,
  required List<AddressEntity>? addresses,
}) {
  if (!isLoggedIn) {
    return 'Log in to add your delivery address';
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

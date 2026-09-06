import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';

class AddressUpsertParams {
  const AddressUpsertParams({
    required this.label,
    required this.addressLine1,
    required this.city,
    required this.state,
    required this.pincode,
    this.addressLine2,
    this.receiverName,
    this.receiverPhone,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  final String label;
  final String addressLine1;
  final String? addressLine2;
  final String? receiverName;
  final String? receiverPhone;
  final String city;
  final String state;
  final String pincode;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'label': label,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'receiverName': receiverName,
      'receiverPhone': receiverPhone,
      'city': city,
      'state': state,
      'pincode': pincode,
      'lat': latitude,
      'lng': longitude,
      'isDefault': isDefault,
    }..removeWhere((key, value) => value == null);
  }
}

class PincodeValidationResult {
  const PincodeValidationResult({
    required this.available,
    required this.deliveryFee,
    required this.estimatedMin,
    this.city,
    this.area,
    this.state,
  });

  final bool available;
  final double deliveryFee;
  final int estimatedMin;

  // Admin-curated override — only present when an active pincode mapping
  // matches (see bakaloo-backend migration 089).
  final String? city;
  final String? area;
  final String? state;
}

abstract class AddressRepository {
  Future<Either<Failure, List<AddressEntity>>> getAddresses();

  Future<Either<Failure, AddressEntity>> createAddress(
    AddressUpsertParams params,
  );

  Future<Either<Failure, AddressEntity>> updateAddress(
    String id,
    AddressUpsertParams params,
  );

  Future<Either<Failure, void>> deleteAddress(String id);

  Future<Either<Failure, AddressEntity>> setDefaultAddress(String id);

  Future<Either<Failure, PincodeValidationResult>> validatePincode(
    String pincode,
  );
}

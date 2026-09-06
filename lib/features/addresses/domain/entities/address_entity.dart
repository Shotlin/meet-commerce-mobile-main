import 'package:freezed_annotation/freezed_annotation.dart';

part 'address_entity.freezed.dart';

@freezed
abstract class AddressEntity with _$AddressEntity {
  const factory AddressEntity({
    required String id,
    required String label,
    required String name,
    required String phone,
    required String addressLine1,
    required String city,
    required String state,
    required String pincode,
    required double latitude,
    required double longitude,
    String? addressLine2,
    String? receiverName,
    String? receiverPhone,
    @Default(false) bool isDefault,
  }) = _AddressEntity;
}

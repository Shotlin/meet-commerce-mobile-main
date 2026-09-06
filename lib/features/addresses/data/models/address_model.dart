import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';

part 'address_model.freezed.dart';
part 'address_model.g.dart';

double _addressDoubleFromJson(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

@freezed
abstract class AddressModel with _$AddressModel {
  const AddressModel._();

  const factory AddressModel({
    required String id,
    required String addressLine1,
    required String city,
    required String pincode,
    @Default('Home') String label,
    @Default('') String state,
    @JsonKey(name: 'lat', fromJson: _addressDoubleFromJson)
    @Default(0)
    double latitude,
    @JsonKey(name: 'lng', fromJson: _addressDoubleFromJson)
    @Default(0)
    double longitude,
    String? addressLine2,
    String? receiverName,
    String? receiverPhone,
    @JsonKey(name: 'isDefault') @Default(false) bool isDefault,
  }) = _AddressModel;

  factory AddressModel.fromJson(Map<String, dynamic> json) =>
      _$AddressModelFromJson(json);

  AddressEntity toEntity({
    required String name,
    required String phone,
  }) {
    return AddressEntity(
      id: id,
      label: _normalizeLabel(label),
      name: name,
      phone: phone,
      receiverName: receiverName,
      receiverPhone: receiverPhone,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      city: city,
      state: state,
      pincode: pincode,
      latitude: latitude,
      longitude: longitude,
      isDefault: isDefault,
    );
  }

  String _normalizeLabel(String rawLabel) {
    final normalized = rawLabel.trim().toLowerCase();
    if (normalized.contains('home')) {
      return 'Home';
    }
    if (normalized.contains('work') || normalized.contains('office')) {
      return 'Work';
    }
    return 'Other';
  }
}

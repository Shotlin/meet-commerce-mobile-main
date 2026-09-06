import 'package:freezed_annotation/freezed_annotation.dart';

part 'rider_location_entity.freezed.dart';

@freezed
abstract class RiderLocationEntity with _$RiderLocationEntity {
  const factory RiderLocationEntity({
    required String orderId,
    required double latitude,
    required double longitude,
    required DateTime updatedAt,
    double? bearing,
    double? speed,
  }) = _RiderLocationEntity;
}

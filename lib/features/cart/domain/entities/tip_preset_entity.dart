import 'package:freezed_annotation/freezed_annotation.dart';

part 'tip_preset_entity.freezed.dart';
part 'tip_preset_entity.g.dart';

double _tipPresetAmountFromJson(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}

@freezed
abstract class TipPresetEntity with _$TipPresetEntity {
  const factory TipPresetEntity({
    @JsonKey(fromJson: _tipPresetAmountFromJson) required double amount,
    String? emoji,
  }) = _TipPresetEntity;

  factory TipPresetEntity.fromJson(Map<String, dynamic> json) =>
      _$TipPresetEntityFromJson(json);
}

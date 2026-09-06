import 'package:freezed_annotation/freezed_annotation.dart';

part 'savings_breakdown_entity.freezed.dart';
part 'savings_breakdown_entity.g.dart';

@freezed
abstract class SavingsBreakdownEntity with _$SavingsBreakdownEntity {
  const factory SavingsBreakdownEntity({
    @Default(0) double total,
    @JsonKey(name: 'breakdown')
    @Default(<SavingsLineItem>[])
    List<SavingsLineItem> items,
  }) = _SavingsBreakdownEntity;

  factory SavingsBreakdownEntity.fromJson(Map<String, dynamic> json) =>
      _$SavingsBreakdownEntityFromJson(json);
}

@freezed
abstract class SavingsLineItem with _$SavingsLineItem {
  const factory SavingsLineItem({
    required String type,
    required String label,
    @Default(0) double amount,
  }) = _SavingsLineItem;

  factory SavingsLineItem.fromJson(Map<String, dynamic> json) =>
      _$SavingsLineItemFromJson(json);
}

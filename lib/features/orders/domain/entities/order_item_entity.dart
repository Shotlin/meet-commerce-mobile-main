import 'package:freezed_annotation/freezed_annotation.dart';

part 'order_item_entity.freezed.dart';

@freezed
abstract class OrderItemEntity with _$OrderItemEntity {
  const factory OrderItemEntity({
    required String productId,
    required String name,
    required double price,
    required int quantity,
    required String unit,
    required double total,
    String? thumbnailUrl,
    String? brand,
    // Only present on orders placed after the backend started capturing
    // it at checkout time — an older order's item has neither, and that's
    // the honest state (no discount was ever recorded for it), not 0.
    double? originalPrice,
    @Default(0) int discountPercent,
  }) = _OrderItemEntity;
}

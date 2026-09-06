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
  }) = _OrderItemEntity;
}

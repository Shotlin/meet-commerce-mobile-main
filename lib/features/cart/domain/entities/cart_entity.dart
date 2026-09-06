import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_item_entity.dart';

part 'cart_entity.freezed.dart';

@freezed
abstract class CartEntity with _$CartEntity {
  const CartEntity._();

  const factory CartEntity({
    required List<CartItemEntity> items,
    required double subtotal,
    required int itemCount,
    @Default(0) double tipAmount,
    String? deliveryInstructions,
  }) = _CartEntity;

  factory CartEntity.empty() =>
      const CartEntity(items: <CartItemEntity>[], subtotal: 0, itemCount: 0);

  bool get isEmpty => items.isEmpty || itemCount == 0;

  double get totalSavings => items.fold<double>(
        0,
        (sum, item) => sum + item.totalSavings,
      );
}

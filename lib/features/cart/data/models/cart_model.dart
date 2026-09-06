import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:bakaloo_flutter_app/features/cart/data/models/cart_item_model.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_entity.dart';

part 'cart_model.freezed.dart';
part 'cart_model.g.dart';

double _cartSubtotalFromJson(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

@freezed
abstract class CartModel with _$CartModel {
  const CartModel._();

  const factory CartModel({
    @Default(<CartItemModel>[]) List<CartItemModel> items,
    @JsonKey(fromJson: _cartSubtotalFromJson) @Default(0) double subtotal,
    @JsonKey(name: 'count') @Default(0) int itemCount,
    @JsonKey(fromJson: _cartSubtotalFromJson) @Default(0) double tipAmount,
    String? deliveryInstructions,
  }) = _CartModel;

  factory CartModel.fromJson(Map<String, dynamic> json) =>
      _$CartModelFromJson(json);

  CartEntity toEntity() {
    return CartEntity(
      items: items.map((item) => item.toEntity()).toList(),
      subtotal: subtotal,
      itemCount: itemCount,
      tipAmount: tipAmount,
      deliveryInstructions: deliveryInstructions,
    );
  }
}

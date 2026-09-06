import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_item_entity.dart';

part 'cart_item_model.freezed.dart';
part 'cart_item_model.g.dart';

double _cartDoubleFromJson(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _cartNullableDoubleFromJson(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}

bool _cartBoolFromJson(Object? value) => value is bool ? value : true;

int _cartStockFromJson(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 9999;
}

@freezed
abstract class CartItemModel with _$CartItemModel {
  const CartItemModel._();

  const factory CartItemModel({
    required String productId,
    required String name,
    @JsonKey(fromJson: _cartDoubleFromJson) required double price,
    required int quantity,
    @JsonKey(name: 'lineTotal', fromJson: _cartDoubleFromJson)
    required double total,
    @JsonKey(name: 'salePrice', fromJson: _cartNullableDoubleFromJson)
    double? salePrice,
    String? unit,
    @JsonKey(name: 'netQuantity') String? netQuantity,
    String? thumbnailUrl,
    @JsonKey(name: 'shopProductId') String? shopProductId,
    @JsonKey(name: 'shopId') String? shopId,
    @JsonKey(name: 'optionLabel') String? optionLabel,
    @JsonKey(name: 'familyName') String? familyName,
    @JsonKey(name: 'foodType') String? foodType,
    @JsonKey(name: 'originTag') String? originTag,
    @JsonKey(name: 'displayDeliveryMinutes') int? displayDeliveryMinutes,
    @JsonKey(name: 'categoryId') String? categoryId,
    @JsonKey(name: 'isAvailable', fromJson: _cartBoolFromJson)
    @Default(true)
    bool isAvailable,
    @JsonKey(name: 'stockQuantity', fromJson: _cartStockFromJson)
    @Default(9999)
    int stockQuantity,
  }) = _CartItemModel;

  factory CartItemModel.fromJson(Map<String, dynamic> json) =>
      _$CartItemModelFromJson(json);

  CartItemEntity toEntity() {
    return CartItemEntity(
      productId: productId,
      name: name,
      price: price,
      salePrice: salePrice,
      quantity: quantity,
      total: total,
      unit: unit,
      netQuantity: netQuantity,
      thumbnailUrl: thumbnailUrl,
      shopProductId: shopProductId,
      shopId: shopId,
      optionLabel: optionLabel,
      familyName: familyName,
      foodType: foodType,
      originTag: originTag,
      displayDeliveryMinutes: displayDeliveryMinutes,
      categoryId: categoryId,
      isAvailable: isAvailable,
      stockQuantity: stockQuantity,
    );
  }
}

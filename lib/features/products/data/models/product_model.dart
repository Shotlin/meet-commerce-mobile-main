import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';

part 'product_model.freezed.dart';
part 'product_model.g.dart';

double _productPriceFromJson(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _productSalePriceFromJson(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}

Map<String, dynamic>? _productMapFromJson(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

List<String> _badgesFromJson(Object? value) {
  if (value is List) {
    return value.whereType<String>().toList();
  }
  return <String>[];
}

@freezed
abstract class ProductModel with _$ProductModel {
  const ProductModel._();

  const factory ProductModel({
    required String id,
    required String name,
    required String slug,
    @JsonKey(fromJson: _productPriceFromJson) required double price,
    @JsonKey(name: 'stock_quantity') required int stockQuantity,
    required String unit,
    @JsonKey(name: 'sale_price', fromJson: _productSalePriceFromJson)
    double? salePrice,
    @JsonKey(name: 'category_id') String? categoryId,
    @JsonKey(name: 'category_name') String? categoryName,
    @Default(<String>[]) List<String> images,
    @JsonKey(name: 'thumbnail_url') String? thumbnailUrl,
    @Default(<String>[]) List<String> tags,
    @JsonKey(name: 'is_featured') @Default(false) bool isFeatured,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'total_sold') @Default(0) int totalSold,
    String? description,
    String? ingredients,
    @JsonKey(name: 'nutrition_info', fromJson: _productMapFromJson)
    Map<String, dynamic>? nutritionInfo,
    @JsonKey(name: 'storage_instructions') String? storageInstructions,
    @JsonKey(name: 'brand') String? brand,
    @JsonKey(name: 'brand_logo_url') String? brandLogoUrl,
    @JsonKey(name: 'net_quantity') String? netQuantity,
    @JsonKey(fromJson: _productMapFromJson) Map<String, dynamic>? highlights,
    List<dynamic>? attributes,
    @JsonKey(name: 'vendor_name') String? vendorName,
    @JsonKey(name: 'vendor_address') String? vendorAddress,
    @JsonKey(name: 'vendor_fssai') String? vendorFssai,
    @JsonKey(name: 'return_policy') @Default('no_return') String returnPolicy,
    @JsonKey(name: 'avg_rating', fromJson: _productPriceFromJson)
    @Default(0.0)
    double avgRating,
    @JsonKey(name: 'rating_count') @Default(0) int ratingCount,
    @JsonKey(name: 'is_authentic') @Default(true) bool isAuthentic,
    // Phase 1/3: product family / option fields
    @JsonKey(name: 'product_family_id') String? productFamilyId,
    @JsonKey(name: 'family_name') String? familyName,
    @JsonKey(name: 'option_label') String? optionLabel,
    @JsonKey(name: 'option_count') @Default(1) int optionCount,
    @JsonKey(name: 'option_sort_order') @Default(0) int optionSortOrder,
    @JsonKey(name: 'is_default_option') @Default(false) bool isDefaultOption,
    @JsonKey(name: 'food_type') @Default('NONE') String foodType,
    @JsonKey(name: 'origin_tag') @Default('NONE') String originTag,
    @JsonKey(name: 'custom_badges', fromJson: _badgesFromJson)
    @Default(<String>[])
    List<String> customBadges,
    @JsonKey(name: 'display_delivery_minutes') int? displayDeliveryMinutes,
    @JsonKey(name: 'shop_product_id') String? shopProductId,
    @JsonKey(name: 'shop_id') String? shopId,
  }) = _ProductModel;

  factory ProductModel.fromJson(Map<String, dynamic> json) =>
      _$ProductModelFromJson(json);

  ProductEntity toEntity() {
    final normalizedImages = images
        .map(ApiConstants.resolveMediaUrl)
        .whereType<String>()
        .where((image) => image.isNotEmpty)
        .toList();
    final normalizedThumbnail = ApiConstants.resolveMediaUrl(thumbnailUrl);
    final resolvedImages = normalizedImages.isNotEmpty
        ? normalizedImages
        : <String>[
            if ((normalizedThumbnail ?? '').isNotEmpty) normalizedThumbnail!,
          ];

    return ProductEntity(
      id: id,
      name: name,
      slug: slug,
      price: price,
      salePrice: salePrice,
      stockQuantity: stockQuantity,
      unit: unit,
      categoryId: categoryId,
      categoryName: categoryName,
      images: resolvedImages,
      thumbnailUrl: normalizedThumbnail,
      tags: tags,
      isFeatured: isFeatured,
      isActive: isActive,
      totalSold: totalSold,
      description: description,
      ingredients: ingredients,
      nutritionInfo: nutritionInfo,
      storageInstructions: storageInstructions,
      brand: brand,
      brandLogoUrl: ApiConstants.resolveMediaUrl(brandLogoUrl),
      netQuantity: netQuantity,
      highlights: highlights,
      attributes:
          attributes?.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      vendorName: vendorName,
      vendorAddress: vendorAddress,
      vendorFssai: vendorFssai,
      returnPolicy: returnPolicy,
      avgRating: avgRating,
      ratingCount: ratingCount,
      isAuthentic: isAuthentic,
      // Phase 1/3: option/family fields
      productFamilyId: productFamilyId,
      familyName: familyName,
      optionLabel: optionLabel,
      optionCount: optionCount,
      optionSortOrder: optionSortOrder,
      isDefaultOption: isDefaultOption,
      foodType: foodType,
      originTag: originTag,
      customBadges: customBadges,
      displayDeliveryMinutes: displayDeliveryMinutes,
      shopProductId: shopProductId,
      shopId: shopId,
    );
  }
}

import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_entity.freezed.dart';

@freezed
abstract class ProductEntity with _$ProductEntity {
  const ProductEntity._();

  const factory ProductEntity({
    required String id,
    required String name,
    required String slug,
    required double price,
    required int stockQuantity,
    required String unit,
    required List<String> images,
    required List<String> tags,
    required bool isFeatured,
    required bool isActive,
    required int totalSold,
    double? salePrice,
    String? categoryId,
    String? categoryName,
    String? thumbnailUrl,
    String? description,
    String? ingredients,
    Map<String, dynamic>? nutritionInfo,
    String? storageInstructions,
    String? brand,
    String? brandLogoUrl,
    String? netQuantity,
    Map<String, dynamic>? highlights,
    List<Map<String, dynamic>>? attributes,
    String? vendorName,
    String? vendorAddress,
    String? vendorFssai,
    @Default('no_return') String returnPolicy,
    @Default(0.0) double avgRating,
    @Default(0) int ratingCount,
    @Default(true) bool isAuthentic,
    // Phase 1/3: product family / option fields
    String? productFamilyId,
    String? familyName,
    String? optionLabel,
    @Default(1) int optionCount,
    @Default(0) int optionSortOrder,
    @Default(false) bool isDefaultOption,
    @Default('NONE') String foodType,
    @Default('NONE') String originTag,
    @Default(<String>[]) List<String> customBadges,
    int? displayDeliveryMinutes,
    String? shopProductId,
    String? shopId,
  }) = _ProductEntity;

  bool get isOnSale =>
      salePrice != null && salePrice! > 0 && salePrice! < price;

  double get effectivePrice => isOnSale ? salePrice! : price;

  bool get inStock => stockQuantity > 0 && isActive;

  bool get lowStock => inStock && stockQuantity < 10;

  String get brandDisplay => brand ?? categoryName ?? '';

  bool get hasHighlights => highlights != null && highlights!.isNotEmpty;

  bool get hasAttributes => attributes != null && attributes!.isNotEmpty;

  bool get hasVendorDetails => vendorName != null && vendorName!.isNotEmpty;

  bool get hasMultipleOptions => optionCount > 1;

  bool get isVeg => foodType == 'VEG';

  bool get isNonVeg => foodType == 'NON_VEG';

  bool get isEgg => foodType == 'EGG';

  bool get hasFoodMarker => foodType != 'NONE';

  bool get isImported => originTag == 'IMPORTED';

  bool get isLocal => originTag == 'LOCAL';

  bool get hasOriginTag => originTag != 'NONE';

  bool get hasBadges => customBadges.isNotEmpty;

  bool get hasDeliveryTime => displayDeliveryMinutes != null && displayDeliveryMinutes! > 0;

  bool get hasRating => avgRating > 0 && ratingCount > 0;

  /// Display label for the option/unit row. Priority: optionLabel > netQuantity > unit.
  String get displayUnit => optionLabel ?? netQuantity ?? unit;

  // A count under 11 reads as "barely reviewed" and undersells a genuinely
  // good product — below that threshold only the average star shows, no
  // number. 11+ is treated as enough reviews for the count itself to be a
  // meaningful trust signal.
  String get formattedRating {
    if (avgRating <= 0) return '';
    if (ratingCount <= 10) return avgRating.toStringAsFixed(1);
    final count = ratingCount >= 1000
        ? '${(ratingCount / 1000).toStringAsFixed(1)}k'
        : '$ratingCount';
    return '${avgRating.toStringAsFixed(1)} ★ $count';
  }

  bool get hasNoReturn => returnPolicy == 'no_return';

  int get discountPercent {
    if (salePrice == null || salePrice! >= price) return 0;
    return (((price - salePrice!) / price) * 100).round();
  }

  double get discountAmount {
    if (salePrice == null || salePrice! >= price) return 0;
    return price - salePrice!;
  }

  String get formattedDeliveryTime {
    if (displayDeliveryMinutes == null || displayDeliveryMinutes! <= 0) return '';
    return '${displayDeliveryMinutes!} mins';
  }
}

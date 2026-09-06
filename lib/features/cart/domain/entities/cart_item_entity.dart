import 'package:freezed_annotation/freezed_annotation.dart';

part 'cart_item_entity.freezed.dart';

@freezed
abstract class CartItemEntity with _$CartItemEntity {
  const CartItemEntity._();

  const factory CartItemEntity({
    required String productId,
    required String name,
    required double price,
    required int quantity,
    required double total,
    double? salePrice,
    String? unit,

    /// Full pack-size string as the shopper should see it (e.g. "200 gm"),
    /// distinct from [unit] which is just the bare unit code (e.g. "g").
    String? netQuantity,
    String? thumbnailUrl,
    String? shopProductId,
    String? shopId,
    String? optionLabel,
    String? familyName,
    String? foodType,
    String? originTag,
    int? displayDeliveryMinutes,
    // Lets the cart screen's own "+" button evaluate a CATEGORY-scoped
    // purchase-limit rule from a cart line alone.
    String? categoryId,
    // A line can go out of stock (or get manually delisted) after it was
    // added — e.g. another customer buying the last unit first while this
    // one sits in this cart. The backend still returns the line (so it
    // stays visible here) but excludes it from subtotal/totalPayable.
    @Default(true) bool isAvailable,
    @Default(9999) int stockQuantity,
  }) = _CartItemEntity;

  /// Mirrors [ProductEntity.inStock]'s convention, but also accounts for
  /// the quantity actually requested — a line can have some stock left
  /// (stockQuantity > 0) yet still not be fulfillable if the customer
  /// already has more of it in their cart than remains.
  bool get hasEnoughStock => isAvailable && stockQuantity >= quantity;

  /// Mirrors [ProductEntity.displayUnit]: prefer the specific option label,
  /// then the full pack-size string, falling back to the bare unit code.
  String get displayUnit => optionLabel ?? netQuantity ?? unit ?? '1 unit';

  double get effectivePrice {
    if (salePrice != null && salePrice! > 0 && salePrice! < price) {
      return salePrice!;
    }
    return price;
  }

  double get savingsPerUnit {
    if (salePrice == null || salePrice! >= price) {
      return 0;
    }
    return price - salePrice!;
  }

  double get totalSavings => savingsPerUnit * quantity;
}

// Plain Dart classes for the product options API response.
// Uses manual fromJson to avoid build_runner complexity.
//
// The backend `/products/:id/options` endpoint serialises shop-enriched
// option rows using snake_case column names (shop_product_id, option_label,
// sale_price, ...), while older builds used camelCase. To stay resilient to
// both shapes (and to differing deploy versions of the production API) the
// parser below reads each field from the camelCase key first and falls back
// to the snake_case key.

class ProductOptionsFamily {
  const ProductOptionsFamily({
    this.id,
    this.name,
    this.slug,
    this.thumbnailUrl,
  });

  final String? id;
  final String? name;
  final String? slug;
  final String? thumbnailUrl;

  factory ProductOptionsFamily.fromJson(Map<String, dynamic> json) {
    return ProductOptionsFamily(
      id: json['id'] as String?,
      name: json['name'] as String?,
      slug: json['slug'] as String?,
      thumbnailUrl: (json['thumbnailUrl'] ?? json['thumbnail_url']) as String?,
    );
  }
}

class ProductOptionItem {
  const ProductOptionItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.isAvailable,
    this.shopProductId,
    this.shopId,
    this.optionLabel,
    this.netQuantity,
    this.salePrice,
    this.stockQuantity,
    this.maxOrderQty,
    this.thumbnailUrl,
    this.images = const <String>[],
    this.foodType = 'NONE',
    this.originTag = 'NONE',
    this.customBadges = const <String>[],
    this.avgRating = 0.0,
    this.ratingCount = 0,
    this.displayDeliveryMinutes,
  });

  final String id;
  final String? shopProductId;
  final String? shopId;
  final String name;
  final String? optionLabel;
  final String unit;
  final String? netQuantity;
  final double price;
  final double? salePrice;
  final int? stockQuantity;
  final int? maxOrderQty;
  final bool isAvailable;
  final String? thumbnailUrl;
  final List<String> images;
  final String foodType;
  final String originTag;
  final List<String> customBadges;
  final double avgRating;
  final int ratingCount;
  final int? displayDeliveryMinutes;

  double get effectivePrice {
    if (salePrice != null && salePrice! > 0 && salePrice! < price) {
      return salePrice!;
    }
    return price;
  }

  int get discountPercent {
    if (salePrice == null || salePrice! >= price || price <= 0) return 0;
    return (((price - salePrice!) / price) * 100).round();
  }

  double get discountAmount {
    if (salePrice == null || salePrice! >= price) return 0;
    return price - salePrice!;
  }

  bool get inStock =>
      isAvailable && (stockQuantity == null || stockQuantity! > 0);

  bool get isVeg => foodType == 'VEG';
  bool get isNonVeg => foodType == 'NON_VEG';
  bool get isEgg => foodType == 'EGG';
  bool get hasFoodMarker => foodType != 'NONE';

  String get displayUnit => optionLabel ?? netQuantity ?? unit;

  factory ProductOptionItem.fromJson(Map<String, dynamic> json) {
    Object? pick(String camel, String snake) => json[camel] ?? json[snake];

    final salePrice = _toNullableDouble(pick('salePrice', 'sale_price'));
    final spSalePrice = _toNullableDouble(json['sp_sale_price']);
    final spPrice = _toNullableDouble(json['sp_price']);

    return ProductOptionItem(
      id: json['id'] as String? ?? '',
      shopProductId: pick('shopProductId', 'shop_product_id') as String?,
      shopId: pick('shopId', 'shop_id') as String?,
      name: json['name'] as String? ?? '',
      optionLabel: pick('optionLabel', 'option_label') as String?,
      unit: json['unit'] as String? ?? 'unit',
      netQuantity: pick('netQuantity', 'net_quantity') as String?,
      price: spPrice ?? _toDouble(json['price']),
      salePrice: spSalePrice ?? salePrice,
      stockQuantity: _toNullableInt(
        pick('stockQuantity', 'stock_quantity') ?? json['sp_stock_quantity'],
      ),
      maxOrderQty: _toNullableInt(
        pick('maxOrderQty', 'max_order_qty') ?? json['sp_max_order_qty'],
      ),
      isAvailable: _toBool(
        pick('isAvailable', 'is_available') ?? json['sp_is_available'],
        fallback: true,
      ),
      thumbnailUrl: pick('thumbnailUrl', 'thumbnail_url') as String?,
      images: _toStringList(json['images']),
      foodType: (pick('foodType', 'food_type') as String?) ?? 'NONE',
      originTag: (pick('originTag', 'origin_tag') as String?) ?? 'NONE',
      customBadges: _toStringList(pick('customBadges', 'custom_badges')),
      avgRating: _toDouble(pick('avgRating', 'avg_rating')),
      ratingCount: _toNullableInt(pick('ratingCount', 'rating_count')) ?? 0,
      displayDeliveryMinutes: _toNullableInt(
        pick('displayDeliveryMinutes', 'display_delivery_minutes'),
      ),
    );
  }
}

class ProductOptionsResponse {
  const ProductOptionsResponse({
    this.family,
    this.options = const <ProductOptionItem>[],
  });

  final ProductOptionsFamily? family;
  final List<ProductOptionItem> options;

  factory ProductOptionsResponse.fromJson(Map<String, dynamic> json) {
    final familyJson = json['family'];
    final optionsJson = json['options'];

    return ProductOptionsResponse(
      family: familyJson is Map
          ? ProductOptionsFamily.fromJson(
              Map<String, dynamic>.from(familyJson),
            )
          : null,
      options: optionsJson is List
          ? optionsJson
              .whereType<Map>()
              .map(
                (item) => ProductOptionItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const <ProductOptionItem>[],
    );
  }
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

double? _toNullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int? _toNullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool _toBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  if (value is num) return value != 0;
  return fallback;
}

List<String> _toStringList(dynamic value) {
  if (value is! List) return const <String>[];
  return value
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
}

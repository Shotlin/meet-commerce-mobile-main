import 'package:bakaloo_flutter_app/features/products/data/models/product_model.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';

List<ProductEntity> _parseProductEntities(dynamic value) {
  if (value is! List) {
    return const <ProductEntity>[];
  }

  return value
      .whereType<Map>()
      .map((Map item) => ProductModel.fromJson(Map<String, dynamic>.from(item)))
      .map((ProductModel product) => product.toEntity())
      .toList(growable: false);
}

class TabCategorySection {
  const TabCategorySection({
    required this.categoryId,
    required this.title,
    required this.products,
  });

  final String categoryId;
  final String title;
  final List<ProductEntity> products;

  factory TabCategorySection.fromJson(Map<String, dynamic> json) =>
      TabCategorySection(
        categoryId: (json['category_id'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        products: _parseProductEntities(json['products']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'category_id': categoryId,
        'title': title,
        'products': products
            .map(
              (ProductEntity product) => ProductModel(
                id: product.id,
                name: product.name,
                slug: product.slug,
                price: product.price,
                stockQuantity: product.stockQuantity,
                unit: product.unit,
                netQuantity: product.netQuantity,
                optionLabel: product.optionLabel,
                salePrice: product.salePrice,
                categoryId: product.categoryId,
                categoryName: product.categoryName,
                images: product.images,
                thumbnailUrl: product.thumbnailUrl,
                tags: product.tags,
                isFeatured: product.isFeatured,
                isActive: product.isActive,
                totalSold: product.totalSold,
                description: product.description,
                ingredients: product.ingredients,
                nutritionInfo: product.nutritionInfo,
                storageInstructions: product.storageInstructions,
              ).toJson(),
            )
            .toList(growable: false),
      };
}

class TabHomeContentResponse {
  const TabHomeContentResponse({
    required this.storeKey,
    required this.tabKey,
    required this.seasonalProducts,
    required this.featuredProducts,
    required this.dealProducts,
    required this.trendingProducts,
    required this.categorySections,
  });

  final String storeKey;
  final String tabKey;
  final List<ProductEntity> seasonalProducts;
  final List<ProductEntity> featuredProducts;
  final List<ProductEntity> dealProducts;
  final List<ProductEntity> trendingProducts;
  final List<TabCategorySection> categorySections;

  factory TabHomeContentResponse.fromJson(Map<String, dynamic> json) =>
      TabHomeContentResponse(
        storeKey: (json['store_key'] as String?) ?? 'zepto',
        tabKey: (json['tab_key'] as String?) ?? 'all',
        seasonalProducts: _parseProductEntities(json['seasonal_products']),
        featuredProducts: _parseProductEntities(json['featured_products']),
        dealProducts: _parseProductEntities(json['deal_products']),
        trendingProducts: _parseProductEntities(json['trending_products']),
        categorySections:
            (json['category_sections'] as List<dynamic>? ?? <dynamic>[])
                .whereType<Map>()
                .map(
                  (Map item) => TabCategorySection.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false),
      );

  static ProductModel _entityToModel(ProductEntity product) => ProductModel(
        id: product.id,
        name: product.name,
        slug: product.slug,
        price: product.price,
        stockQuantity: product.stockQuantity,
        unit: product.unit,
        salePrice: product.salePrice,
        categoryId: product.categoryId,
        categoryName: product.categoryName,
        images: product.images,
        thumbnailUrl: product.thumbnailUrl,
        tags: product.tags,
        isFeatured: product.isFeatured,
        isActive: product.isActive,
        totalSold: product.totalSold,
        description: product.description,
        ingredients: product.ingredients,
        nutritionInfo: product.nutritionInfo,
        storageInstructions: product.storageInstructions,
        productFamilyId: product.productFamilyId,
        familyName: product.familyName,
        optionLabel: product.optionLabel,
        optionCount: product.optionCount,
        optionSortOrder: product.optionSortOrder,
        isDefaultOption: product.isDefaultOption,
        foodType: product.foodType,
        originTag: product.originTag,
        customBadges: product.customBadges,
        displayDeliveryMinutes: product.displayDeliveryMinutes,
        shopProductId: product.shopProductId,
        shopId: product.shopId,
        netQuantity: product.netQuantity,
        brand: product.brand,
        brandLogoUrl: product.brandLogoUrl,
        avgRating: product.avgRating,
        ratingCount: product.ratingCount,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'store_key': storeKey,
        'tab_key': tabKey,
        'seasonal_products': seasonalProducts
            .map((ProductEntity p) => _entityToModel(p).toJson())
            .toList(growable: false),
        'featured_products': featuredProducts
            .map((ProductEntity p) => _entityToModel(p).toJson())
            .toList(growable: false),
        'deal_products': dealProducts
            .map((ProductEntity p) => _entityToModel(p).toJson())
            .toList(growable: false),
        'trending_products': trendingProducts
            .map((ProductEntity p) => _entityToModel(p).toJson())
            .toList(growable: false),
        'category_sections': categorySections
            .map((TabCategorySection section) => section.toJson())
            .toList(growable: false),
      };
}

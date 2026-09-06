import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/shared/entities/pagination_entity.dart';

class CategoryLocalDataSource {
  const CategoryLocalDataSource();

  List<Map<String, dynamic>>? getCategories() {
    final value = HiveService.categoriesBox.get('categories_all');
    if (value is List) {
      return value
          .whereType<Map>()
          .map((Map item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return null;
  }

  Future<void> cacheCategories(List<Map<String, dynamic>> categories) async {
    await HiveService.categoriesBox.put('categories_all', categories);
    await HiveService.markCached('categories_all');
  }

  Map<String, dynamic>? getCategoryProducts(String categoryId) {
    final value = HiveService.categoriesBox.get(_productsKey(categoryId));
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  Future<void> cacheCategoryProducts({
    required String categoryId,
    required List<Map<String, dynamic>> items,
    required PaginationEntity pagination,
  }) async {
    final key = _productsKey(categoryId);
    await HiveService.categoriesBox.put(
      key,
      <String, dynamic>{
        'items': items,
        'pagination': pagination.toJson(),
      },
    );
    await HiveService.markCached(key);
  }

  bool isFresh(String key, Duration ttl) => HiveService.isFresh(key, ttl);

  String productsCacheKey(String categoryId) => _productsKey(categoryId);

  String _productsKey(String categoryId) => 'category_products_$categoryId';
}

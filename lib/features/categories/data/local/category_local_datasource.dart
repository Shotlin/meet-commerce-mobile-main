import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';
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

  /// [key] is a full key from [productsCacheKey], captured when the request
  /// started — never rebuilt from mutable state after an `await`.
  Map<String, dynamic>? getCategoryProducts(String key) {
    final value = HiveService.categoriesBox.get(key);
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  Future<void> cacheCategoryProducts({
    required String key,
    required List<Map<String, dynamic>> items,
    required PaginationEntity pagination,
  }) async {
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

  /// Category products are shop- and price-mode-specific server-side, so the
  /// cached copy is keyed by both: a category cached for Store A is never
  /// served as Store B's, nor a retail list as a wholesale one.
  String productsCacheKey(String categoryId) => AppCacheManager.scopedKey(
        'category_products_$categoryId',
        shopScope: AppCacheManager.currentShopScope,
        extra: AppCacheManager.currentPriceMode,
      );
}

import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/shared/entities/pagination_entity.dart';

class ProductLocalDataSource {
  const ProductLocalDataSource();

  Map<String, dynamic>? getCachedList(String key) {
    final value = HiveService.productsBox.get(key);
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  Future<void> cacheList({
    required String key,
    required List<Map<String, dynamic>> items,
    required PaginationEntity pagination,
  }) async {
    await HiveService.productsBox.put(
      key,
      <String, dynamic>{
        'items': items,
        'pagination': pagination.toJson(),
      },
    );
    await HiveService.markCached(key);
  }

  Map<String, dynamic>? getCachedProduct(String productId) {
    final value = HiveService.productsBox.get(_detailKey(productId));
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  Future<void> cacheProduct({
    required String productId,
    required Map<String, dynamic> product,
  }) async {
    final key = _detailKey(productId);
    await HiveService.productsBox.put(key, product);
    await HiveService.markCached(key);
  }

  bool isFresh(String key, Duration ttl) => HiveService.isFresh(key, ttl);

  String detailCacheKey(String productId) => _detailKey(productId);

  String _detailKey(String productId) => 'product_detail_$productId';
}

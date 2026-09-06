import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/shared/entities/pagination_entity.dart';

class OrderLocalDataSource {
  const OrderLocalDataSource();

  static const Duration ttl = Duration(minutes: 5);

  Map<String, dynamic>? getCachedOrderList(String key) {
    final value = HiveService.ordersBox.get(key);
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  Future<void> cacheOrderList({
    required String key,
    required List<Map<String, dynamic>> items,
    required PaginationEntity pagination,
  }) async {
    await HiveService.ordersBox.put(
      key,
      <String, dynamic>{
        'items': items,
        'pagination': pagination.toJson(),
      },
    );
    await HiveService.markCached(key);
  }

  Map<String, dynamic>? getCachedOrderDetail(String orderId) {
    final value = HiveService.ordersBox.get(_detailKey(orderId));
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  Future<void> cacheOrderDetail(
    String orderId,
    Map<String, dynamic> orderJson,
  ) async {
    final key = _detailKey(orderId);
    await HiveService.ordersBox.put(key, orderJson);
    await HiveService.markCached(key);
  }

  Map<String, dynamic>? getCachedActiveOrder() {
    final value = HiveService.ordersBox.get(_activeKey);
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  Future<void> cacheActiveOrder(Map<String, dynamic>? orderJson) async {
    if (orderJson == null) {
      await HiveService.ordersBox.delete(_activeKey);
      await HiveService.invalidate(_activeKey);
      return;
    }
    await HiveService.ordersBox.put(_activeKey, orderJson);
    await HiveService.markCached(_activeKey);
  }

  bool isFresh(String key, Duration cacheTtl) =>
      HiveService.isFresh(key, cacheTtl);

  Future<void> invalidateOrder(String orderId) async {
    final key = _detailKey(orderId);
    await HiveService.ordersBox.delete(key);
    await HiveService.invalidate(key);
    await HiveService.ordersBox.delete(_activeKey);
    await HiveService.invalidate(_activeKey);
  }

  Future<void> invalidateAllListCaches() async {
    final keysToDelete = HiveService.ordersBox.keys
        .whereType<String>()
        .where((key) => key.startsWith(_listPrefix))
        .toList(growable: false);

    for (final key in keysToDelete) {
      await HiveService.ordersBox.delete(key);
      await HiveService.invalidate(key);
    }
  }

  String listCacheKey({
    required String filterKey,
    required int page,
    required int limit,
  }) {
    return '$_listPrefix${filterKey}_page_${page}_$limit';
  }

  String detailCacheKey(String orderId) => _detailKey(orderId);

  String get activeCacheKey => _activeKey;

  static const String _listPrefix = 'orders_list_';
  static const String _activeKey = 'orders_active';

  String _detailKey(String orderId) => 'order_detail_$orderId';
}

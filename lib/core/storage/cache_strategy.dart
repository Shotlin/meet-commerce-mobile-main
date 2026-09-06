import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';

enum CacheMode {
  cacheFirst,
  networkFirst,
  serverAuthoritative,
}

class CachePolicy {
  const CachePolicy({
    required this.key,
    required this.location,
    required this.mode,
    required this.invalidation,
    this.ttl,
  });

  final String key;
  final String location;
  final CacheMode mode;
  final Duration? ttl;
  final String invalidation;
}

class CacheStrategy {
  CacheStrategy._();

  static const categories = CachePolicy(
    key: StorageKeys.cacheCategories,
    location: 'Hive + memory',
    mode: CacheMode.cacheFirst,
    ttl: Duration(minutes: 30),
    invalidation: 'App restart or admin update',
  );

  static const featuredProducts = CachePolicy(
    key: StorageKeys.cacheFeatured,
    location: 'Hive',
    mode: CacheMode.cacheFirst,
    ttl: Duration(minutes: 15),
    invalidation: 'TTL or pull-to-refresh',
  );

  static CachePolicy productDetail(String productId) {
    return CachePolicy(
      key: StorageKeys.cacheProduct(productId),
      location: 'Hive',
      mode: CacheMode.cacheFirst,
      ttl: const Duration(minutes: 10),
      invalidation: 'TTL',
    );
  }

  static const searchHistory = CachePolicy(
    key: StorageKeys.searchHistoryBox,
    location: 'Hive',
    mode: CacheMode.cacheFirst,
    invalidation: 'User clears',
  );

  static const banners = CachePolicy(
    key: StorageKeys.cacheBanners,
    location: 'Hive',
    mode: CacheMode.cacheFirst,
    ttl: Duration(minutes: 20),
    invalidation: 'TTL',
  );

  static const cart = CachePolicy(
    key: 'cart',
    location: 'Server-authoritative',
    mode: CacheMode.serverAuthoritative,
    invalidation: 'Invalidate after every mutation',
  );

  static const orders = CachePolicy(
    key: StorageKeys.cacheOrders,
    location: 'Hive',
    mode: CacheMode.networkFirst,
    ttl: Duration(minutes: 5),
    invalidation: 'Socket event triggers refresh',
  );

  static const userProfile = CachePolicy(
    key: StorageKeys.cacheUserProfile,
    location: 'Hive',
    mode: CacheMode.cacheFirst,
    ttl: Duration(hours: 1),
    invalidation: 'Profile update invalidates',
  );
}

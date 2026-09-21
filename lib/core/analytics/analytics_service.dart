import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/analytics/analytics_events.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((Ref ref) {
  return const AnalyticsService();
});

class AnalyticsService {
  const AnalyticsService();

  FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  Future<void> logProductView(
    String productId,
    String? categoryId,
  ) {
    return _safeLog(
      AnalyticsEvents.productView,
      <String, Object?>{
        'product_id': productId,
        'category_id': categoryId,
      },
    );
  }

  Future<void> logProductImageSwipe(
    String productId,
    int imageIndex,
  ) {
    return _safeLog(
      AnalyticsEvents.productImageSwipe,
      <String, Object?>{
        'product_id': productId,
        'image_index': imageIndex,
      },
    );
  }

  Future<void> logProductHighlightsView(String productId) {
    return _safeLog(
      AnalyticsEvents.productHighlightsView,
      <String, Object?>{
        'product_id': productId,
      },
    );
  }

  Future<void> logProductDetailsExpand(
    String productId,
    String sectionName,
  ) {
    return _safeLog(
      AnalyticsEvents.productDetailsExpand,
      <String, Object?>{
        'product_id': productId,
        'section_name': sectionName,
      },
    );
  }

  Future<void> logProductPairWithTap(
    String productId,
    String targetProductId,
  ) {
    return _safeLog(
      AnalyticsEvents.productPairWithTap,
      <String, Object?>{
        'product_id': productId,
        'target_product_id': targetProductId,
      },
    );
  }

  Future<void> logProductSimilarTap(
    String productId,
    String targetProductId,
  ) {
    return _safeLog(
      AnalyticsEvents.productSimilarTap,
      <String, Object?>{
        'product_id': productId,
        'target_product_id': targetProductId,
      },
    );
  }

  Future<void> logProductBrandTap(
    String productId,
    String brand,
  ) {
    return _safeLog(
      AnalyticsEvents.productBrandTap,
      <String, Object?>{
        'product_id': productId,
        'brand': brand,
      },
    );
  }

  Future<void> logAddToCart(
    String productId,
    int quantity,
    double price,
  ) {
    return _safeLog(
      AnalyticsEvents.addToCart,
      <String, Object?>{
        'product_id': productId,
        'quantity': quantity,
        'price': price,
      },
    );
  }

  Future<void> logWishlistToggle(
    String productId,
    String action,
  ) {
    return _safeLog(
      AnalyticsEvents.wishlistToggle,
      <String, Object?>{
        'product_id': productId,
        'action': action,
      },
    );
  }

  Future<void> logBeginCheckout(
    double total,
    int itemCount,
  ) {
    return _safeLog(
      AnalyticsEvents.beginCheckout,
      <String, Object?>{
        'cart_total': total,
        'item_count': itemCount,
      },
    );
  }

  Future<void> logPurchase(
    String orderId,
    double total,
    String method,
  ) {
    return _safeLog(
      AnalyticsEvents.purchase,
      <String, Object?>{
        'order_id': orderId,
        'total': total,
        'method': method,
      },
    );
  }

  Future<void> logSearch(
    String query,
    int resultCount,
  ) {
    return _safeLog(
      AnalyticsEvents.search,
      <String, Object?>{
        'query': query,
        'result_count': resultCount,
      },
    );
  }

  Future<void> logCouponApplied(
    String code,
    double discount,
  ) {
    return _safeLog(
      AnalyticsEvents.couponApplied,
      <String, Object?>{
        'code': code,
        'discount': discount,
      },
    );
  }

  Future<void> _safeLog(
    String name,
    Map<String, Object?> params,
  ) async {
    try {
      final payload = Map<String, Object>.fromEntries(
        params.entries
            .where(
              (entry) => entry.value != null,
            )
            .map(
              (entry) => MapEntry<String, Object>(
                entry.key,
                entry.value as Object,
              ),
            ),
      );
      await _analytics.logEvent(name: name, parameters: payload);
    } catch (_) {
      // Analytics should never break user flow.
    }
  }
}

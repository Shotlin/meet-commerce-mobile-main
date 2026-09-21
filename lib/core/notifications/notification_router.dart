import 'package:flutter/foundation.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';

/// Maps FCM data payload to an in-app GoRouter path.
///
/// Priority:
///   1. Explicit `deepLink` field in data — validated against known routes
///   2. Type-based routing with ID fields
///   3. null → no navigation (stay on current screen)
class NotificationRouter {
  NotificationRouter._();

  /// All valid top-level path prefixes registered in AppRouter.
  /// Used to guard against stale / wrong deep-link values sent from the
  /// dashboard (e.g. `/notifications` instead of `/profile/notifications`).
  static const _knownPrefixes = <String>[
    '/home',
    '/profile',
    '/orders',
    '/cart',
    '/categories',
    '/product/',
    '/search',
    '/splash',
    '/auth/',
    '/off_zone',
    '/super_mall',
    '/cafe',
    '/location-unavailable',
  ];

  static String? getPath(Map<String, dynamic> data) {
    // 1. Explicit deepLink field takes priority — but only if it matches a
    //    known route prefix so stale/wrong values don't crash navigation.
    final deepLink = _readString(data, const ['deepLink', 'deep_link']);
    if (deepLink.isNotEmpty && deepLink.startsWith('/')) {
      if (_isKnownPath(deepLink)) {
        return deepLink;
      } else {
        // Sanitise legacy wrong paths sent from old dashboard versions.
        final sanitised = _sanitiseDeepLink(deepLink);
        if (sanitised != null) {
          debugPrint(
            '[NotificationRouter] Remapped stale deep link '
            '"$deepLink" → "$sanitised"',
          );
          return sanitised;
        }
        debugPrint(
          '[NotificationRouter] Unknown deep link "$deepLink", '
          'falling back to type-based routing.',
        );
        // Fall through to type-based routing rather than crashing.
      }
    }

    final type = _readString(
      data,
      const ['type', 'notificationType'],
    ).toUpperCase();

    final orderId = _readString(data, const ['orderId', 'order_id']);
    final productId = _readString(data, const ['productId', 'product_id']);
    final categoryId = _readString(data, const ['categoryId', 'category_id']);

    // 2. Type-based routing
    switch (type) {
      case 'ORDER_STATUS':
      case 'ORDER_UPDATE':
        return orderId.isEmpty ? RouteNames.orders : '/orders/$orderId';

      case 'PAYMENT':
      case 'WALLET':
        return RouteNames.wallet;

      case 'PROMOTION':
      case 'OFFER':
      case 'COUPON':
        return RouteNames.categories;

      case 'DELIVERY':
      case 'RIDER_UPDATE':
        return orderId.isEmpty ? null : '/orders/$orderId/track';

      case 'CAMPAIGN':
      case 'ADMIN_BROADCAST':
      case 'SYSTEM':
        return RouteNames.notifications;

      case 'RESTOCK':
      case 'PRODUCT_OFFER':
        if (productId.isNotEmpty) return '/product/$productId';
        return RouteNames.categories;

      case 'CATEGORY_OFFER':
        if (categoryId.isNotEmpty) return '/categories/$categoryId/products';
        return RouteNames.categories;

      case 'CART_REMINDER':
        return RouteNames.cart;

      default:
        return RouteNames.notifications;
    }
  }

  /// Returns true if the path starts with a known valid prefix.
  static bool _isKnownPath(String path) {
    for (final prefix in _knownPrefixes) {
      if (path == prefix ||
          path.startsWith('$prefix/') ||
          path.startsWith('$prefix?')) {
        return true;
      }
    }
    return false;
  }

  /// Remaps known legacy wrong deep-link values to their correct paths.
  /// Covers typos / old dashboard presets that used short paths.
  static String? _sanitiseDeepLink(String path) {
    // Strip query string for comparison, re-attach after remapping.
    final qIdx = path.indexOf('?');
    final base = qIdx == -1 ? path : path.substring(0, qIdx);
    final query = qIdx == -1 ? '' : path.substring(qIdx);

    const remaps = <String, String>{
      '/notifications': RouteNames.notifications,   // was /profile/notifications
      '/wallet':        RouteNames.wallet,           // was /profile/wallet
      '/wishlist':      RouteNames.wishlist,         // was /profile/wishlist
      '/settings':      RouteNames.settings,         // was /profile/settings
      '/reviews':       RouteNames.myReviews,        // was /profile/reviews
      '/addresses':     RouteNames.addresses,        // was /profile/addresses
    };

    final mapped = remaps[base];
    if (mapped != null) return '$mapped$query';
    return null;
  }

  static String _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }
}

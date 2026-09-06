import 'package:bakaloo_flutter_app/routing/route_names.dart';

class RouteAccess {
  RouteAccess._();

  /// Prefixes that require authentication.
  /// Everything else is freely accessible (industry-standard blacklist).
  static const _protectedPrefixes = <String>[
    '/cart',
    '/orders',
    '/profile',
  ];

  static bool isProtectedLocation(String location) {
    final normalized = _normalize(location);

    for (final prefix in _protectedPrefixes) {
      if (normalized == prefix || normalized.startsWith('$prefix/')) {
        return true;
      }
    }

    return false;
  }

  static bool isProtectedTab(String path) {
    final normalized = _normalize(path);
    return normalized == RouteNames.orders || normalized == RouteNames.profile;
  }

  static String _normalize(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return RouteNames.home;
    }

    return trimmed.endsWith('/') && trimmed.length > 1
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}

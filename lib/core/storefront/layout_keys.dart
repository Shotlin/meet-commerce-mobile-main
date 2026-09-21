import 'package:flutter/foundation.dart';

/// Identifies one cached/fetched theme manifest (`GET /theme/tabs`).
///
/// A theme depends on the storefront (`storeKey`) and the fulfilment shop the
/// customer is served by (`shopScope`), but NOT on the B2C/B2B price mode.
///
/// Keys are immutable values captured when a request STARTS. They are never
/// re-derived from mutable global state afterwards, so a response can only ever
/// be written under the key it was requested for (a late Store A response can
/// never land in Store B's cache).
@immutable
class ThemeKey {
  const ThemeKey({required this.storeKey, required this.shopScope});

  final String storeKey;

  /// `anon` or the sorted allocated shop ids joined with `,`
  /// (see `AppCacheManager.currentShopScope`).
  final String shopScope;

  /// Stable string form, used as (part of) the persistent cache key.
  String get id => '$storeKey|$shopScope';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThemeKey &&
          other.storeKey == storeKey &&
          other.shopScope == shopScope;

  @override
  int get hashCode => Object.hash(storeKey, shopScope);

  @override
  String toString() => 'ThemeKey($id)';
}

/// Identifies one cached/fetched section manifest
/// (`GET /theme/tabs/:tab/sections`).
///
/// Section manifests embed shop-scoped, price-mode-scoped products, so the
/// price mode is part of the key: retail and wholesale manifests live side by
/// side and switching between them never invalidates the other.
@immutable
class SectionKey {
  const SectionKey({
    required this.storeKey,
    required this.shopScope,
    required this.priceMode,
    required this.tabKey,
  });

  final String storeKey;
  final String shopScope;

  /// `retail` | `wholesale`.
  final String priceMode;
  final String tabKey;

  ThemeKey get themeKey => ThemeKey(storeKey: storeKey, shopScope: shopScope);

  String get id => '$storeKey|$shopScope|$priceMode|$tabKey';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SectionKey &&
          other.storeKey == storeKey &&
          other.shopScope == shopScope &&
          other.priceMode == priceMode &&
          other.tabKey == tabKey;

  @override
  int get hashCode => Object.hash(storeKey, shopScope, priceMode, tabKey);

  @override
  String toString() => 'SectionKey($id)';
}

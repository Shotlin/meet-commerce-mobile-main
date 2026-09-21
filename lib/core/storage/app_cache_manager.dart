import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';

/// Single source of truth for app-wide cache invalidation policy.
///
/// PHASE 2 FIX (mobile-network stale-UI bug):
///   The previous code only versioned the *remote layout* cache. Theme,
///   product, category, banner, wallet and cart snapshot caches could all
///   survive an app update or a user switch and render old/stale UI when a
///   mobile-data request timed out and the app fell back to cache.
///
/// This manager enforces three rules on every cold start:
///   1. APP_CACHE_SCHEMA_VERSION bump → wipe ALL non-auth caches.
///   2. API base URL change (e.g. staging → prod) → wipe ALL non-auth caches
///      so a cache built against a different backend can never render.
///   3. Logged-in user change → wipe user-specific caches (cart/wallet/orders)
///      so demo-user data never leaks into a real user's session and vice
///      versa.
///
/// Auth tokens (secure storage) and the encrypted user box are never touched
/// here — session continuity is preserved.
class AppCacheManager {
  AppCacheManager._();

  /// Bump this whenever ANY cached payload schema changes in a way that would
  /// render stale/wrong UI from an older build.
  // v5: storefront layout/banner/featured/category-product caches are now keyed
  // by an explicit (store, shop scope, price mode, tab) key captured when the
  // request STARTS. Entries written by older builds computed their key from
  // mutable global state when the response ARRIVED, so a response requested
  // under one shop/price mode could be stored under another — they are wiped
  // once rather than trusted.
  static const int appCacheSchemaVersion = 5;

  static const String _schemaVersionKey = 'bakaloo_app_cache_schema_version';
  static const String _apiBaseUrlKey = 'bakaloo_app_cache_api_base_url';
  static const String _lastUserIdKey = 'bakaloo_app_cache_last_user_id';

  static const String _shopScopeKey = 'bakaloo_app_cache_shop_scope';
  static const String _recentScopesKey = 'bakaloo_app_cache_recent_scopes';

  /// How many distinct shop scopes keep their persisted storefront caches.
  /// Entries of older scopes are pruned when the scope changes.
  static const int _retainedScopeCount = 4;

  /// Separator between a base cache key and its shop scope. A scoped key is
  /// `<base>@<shopScope>[@<extra>]`; [scopeOfKey] recovers the scope.
  static const String scopeSeparator = '@';

  /// The literal scope for anonymous/unallocated browsing — mirrors the
  /// backend's `_scopeKey` in products.service.js, which returns 'anon' for
  /// callers with no resolved shop allocation.
  static const String anonShopScope = 'anon';

  static final ValueNotifier<String> _shopScopeNotifier =
      ValueNotifier<String>(anonShopScope);
  static bool _shopScopeSeeded = false;

  static final ValueNotifier<int> _layoutCacheEpoch = ValueNotifier<int>(0);

  /// Fires with the new scope AFTER it has been persisted. Riverpod's
  /// `shopScopeProvider` mirrors this, which is how every storefront provider
  /// learns about a shop change without a hand-maintained invalidation list.
  static ValueListenable<String> get shopScopeListenable {
    _seedShopScope();
    return _shopScopeNotifier;
  }

  /// Bumped whenever persisted storefront caches are wiped so in-memory copies
  /// (the layout repository's LRU) are dropped with them.
  static ValueListenable<int> get layoutCacheEpoch => _layoutCacheEpoch;

  static void _seedShopScope() {
    if (_shopScopeSeeded) {
      return;
    }
    try {
      final stored = HiveService.settingsBox.get(_shopScopeKey) as String?;
      _shopScopeNotifier.value =
          (stored == null || stored.isEmpty) ? anonShopScope : stored;
      _shopScopeSeeded = true;
    } catch (_) {
      // Hive not ready yet — stay on 'anon' and retry on the next read.
    }
  }

  /// Test hook: forget the in-memory scope mirror (Hive stays untouched).
  @visibleForTesting
  static void debugResetScopeMirror() {
    _shopScopeSeeded = false;
    _shopScopeNotifier.value = anonShopScope;
    _layoutCacheEpoch.value = 0;
  }

  /// Builds a scope-tagged persistent key: `<base>@<shopScope>[@<extra>]`.
  ///
  /// [shopScope] MUST be captured by the caller when the operation starts (not
  /// re-read after an `await`) — see the note on `ThemeKey`.
  static String scopedKey(
    String base, {
    required String shopScope,
    String? extra,
  }) =>
      extra == null
          ? '$base$scopeSeparator$shopScope'
          : '$base$scopeSeparator$shopScope$scopeSeparator$extra';

  /// The shop scope encoded in a key built by [scopedKey], or null.
  static String? scopeOfKey(String key) {
    final int first = key.indexOf(scopeSeparator);
    if (first < 0) {
      return null;
    }
    final int second = key.indexOf(scopeSeparator, first + 1);
    return key.substring(first + 1, second < 0 ? key.length : second);
  }

  /// Call once after [HiveService.init], before the first screen renders.
  /// Wipes stale caches when the schema version or API base URL changed.
  static Future<void> ensureFreshOnStartup() async {
    try {
      final settings = HiveService.settingsBox;

      final storedVersionRaw = settings.get(_schemaVersionKey);
      final storedVersion = storedVersionRaw is int
          ? storedVersionRaw
          : int.tryParse('$storedVersionRaw') ?? 0;

      final storedBaseUrl = settings.get(_apiBaseUrlKey) as String?;
      final currentBaseUrl = ApiConstants.baseUrl;

      final versionChanged = storedVersion != appCacheSchemaVersion;
      final baseUrlChanged =
          storedBaseUrl != null && storedBaseUrl != currentBaseUrl;

      if (versionChanged || baseUrlChanged) {
        debugPrint(
          '[AppCacheManager] Cache reset — '
          'versionChanged=$versionChanged (stored=$storedVersion '
          'current=$appCacheSchemaVersion) '
          'baseUrlChanged=$baseUrlChanged (stored=$storedBaseUrl '
          'current=$currentBaseUrl)',
        );
        await _clearAllNonAuthCaches();
      }

      await settings.put(_schemaVersionKey, appCacheSchemaVersion);
      await settings.put(_apiBaseUrlKey, currentBaseUrl);
    } catch (error) {
      debugPrint('[AppCacheManager] ensureFreshOnStartup failed: $error');
    }
  }

  /// Call right after a confirmed login/session restore once the user id is
  /// known. If the user changed since the last session, wipe user-specific
  /// caches (cart/wallet/orders snapshots, profile cache) so no cross-user
  /// leakage occurs (demo ↔ real user).
  static Future<void> reconcileUser(String? userId) async {
    try {
      final settings = HiveService.settingsBox;
      final storedUserId = settings.get(_lastUserIdKey) as String?;
      final normalized = (userId ?? '').trim();

      if (storedUserId != null && storedUserId != normalized) {
        debugPrint(
          '[AppCacheManager] User changed '
          '(stored=$storedUserId current=$normalized) — '
          'clearing user-specific caches.',
        );
        await _clearUserSpecificCaches();
      }

      await settings.put(_lastUserIdKey, normalized);
    } catch (error) {
      debugPrint('[AppCacheManager] reconcileUser failed: $error');
    }
  }

  /// Clears everything except auth tokens and the encrypted user box.
  static Future<void> _clearAllNonAuthCaches() async {
    await _safeClearBox(HiveService.productsBox);
    await _safeClearBox(HiveService.categoriesBox);
    await _safeClearBox(HiveService.bannersBox);
    await _safeClearBox(HiveService.ordersBox);
    await _safeClearBox(HiveService.remoteThemeBox);
    await _safeClearBox(HiveService.cacheMetaBox);
    await _safeClearBox(HiveService.sectionManifestBox);
    _layoutCacheEpoch.value++;
    try {
      final settings = HiveService.settingsBox;
      await settings.delete(StorageKeys.cacheUserProfile);
      await settings.delete(StorageKeys.cacheAddresses);
    } catch (_) {
      // best-effort
    }
  }

  /// Clears the local product/category/theme caches that are now scoped to
  /// the customer's allocated shop, not "public" — that assumption held
  /// before multi-store existed (one shop, one catalog, same for everyone),
  /// but no longer does. ProductRepositoryImpl's page-1 product list cache
  /// in particular is stale-while-revalidate with a 10-minute TTL keyed only
  /// by page/limit (never by shop), so a page fetched before a customer's
  /// allocation resolved (or before it changed) to a different store would
  /// otherwise keep being served — correctly scoped server responses never
  /// even get requested until the TTL naturally expires.
  ///
  /// Call this whenever the customer's shop allocation may have changed:
  /// login/session-restore and after allocation auto-assign/recompute
  /// (see auth_notifier.dart and allocation_recompute.dart).
  ///
  /// NOTE: a plain shop-scope or price-mode change no longer calls this. Every
  /// storefront cache key now embeds the shop scope (and price mode), so
  /// entries of another scope are simply never read. This is reserved for the
  /// cases where the cached data itself can no longer be trusted (schema bump,
  /// different signed-in user).
  static Future<void> clearShopScopedCaches() async {
    await _safeClearBox(HiveService.productsBox);
    await _safeClearBox(HiveService.categoriesBox);
    await _safeClearBox(HiveService.bannersBox);
    await _safeClearBox(HiveService.remoteThemeBox);
    await _safeClearBox(HiveService.sectionManifestBox);
    _layoutCacheEpoch.value++;
  }

  /// The current customer's shop-allocation scope, as a stable string derived
  /// from their allocated shop id(s) — 'anon' when unresolved/anonymous.
  ///
  /// Read synchronously by ProductRepositoryImpl and folded into its Hive
  /// cache keys, so a different allocation (or no allocation at all) can
  /// never read another scope's cached product list — the two live under
  /// different keys entirely rather than depending on cache invalidation
  /// happening to run before the next read. This mirrors the backend's
  /// products.service.js `_scopeKey`, which does the same thing server-side.
  static String get currentShopScope {
    try {
      final stored = HiveService.settingsBox.get(_shopScopeKey) as String?;
      return (stored == null || stored.isEmpty) ? anonShopScope : stored;
    } catch (_) {
      return anonShopScope;
    }
  }

  /// The B2C/B2B browsing mode as `retail` | `wholesale`. Like
  /// [currentShopScope], callers must capture it when an operation STARTS.
  static String get currentPriceMode {
    try {
      final stored = HiveService.settingsBox.get(StorageKeys.priceMode);
      return stored == 'wholesale' ? 'wholesale' : 'retail';
    } catch (_) {
      return 'retail';
    }
  }

  /// Call after any allocation call (auto-assign/recompute) resolves with a
  /// shop id list — including an empty list, which maps to [anonShopScope].
  /// Clears the shop-scoped caches only when the scope actually changed, so
  /// unrelated calls (e.g. a recompute that confirms the same shop) don't pay
  /// for a needless refetch.
  static Future<void> setShopScope(List<String> shopIds) async {
    final sorted = [...shopIds]..sort();
    final next = sorted.isEmpty ? anonShopScope : sorted.join(',');
    await _applyShopScope(next);
  }

  /// Call on logout so the next anonymous session (or a different customer
  /// logging in on the same device) never reads the previous customer's
  /// shop-scoped cache before their own allocation resolves.
  static Future<void> resetShopScope() => _applyShopScope(anonShopScope);

  /// Parses an allocation endpoint's response body — auto-assign and
  /// recompute are both shaped `{success, message, data: {shops: [...]}}`
  /// server-side (see allocation.routes.js / allocation.service.js
  /// `getForUser`), with each shop object carrying a `shop_id` — and applies
  /// the resulting scope via [setShopScope]. Best-effort: an unexpected shape
  /// (or an empty/absent shops list, e.g. no address yet) just leaves the
  /// scope as anonymous rather than throwing.
  static Future<void> applyAllocationResponse(dynamic responseData) async {
    try {
      final data = responseData is Map ? responseData['data'] : null;
      final shops = data is Map ? data['shops'] : null;
      if (shops is! List) {
        return;
      }
      final shopIds = shops
          .whereType<Map>()
          .map((shop) => shop['shop_id'])
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();
      await setShopScope(shopIds);
    } catch (error) {
      debugPrint('[AppCacheManager] applyAllocationResponse failed: $error');
    }
  }

  /// Commits a new shop scope: persist first, THEN publish it.
  ///
  /// Nothing is wiped here. Storefront caches are keyed by scope, so the old
  /// scope's entries stay valid for that scope (instant return to a previous
  /// shop) and can never be read under the new one. Entries of scopes that are
  /// no longer among the [_retainedScopeCount] most recent are pruned so the
  /// boxes stay bounded.
  static Future<void> _applyShopScope(String next) async {
    try {
      final settings = HiveService.settingsBox;
      final current = settings.get(_shopScopeKey) as String?;
      if (current != next) {
        await settings.put(_shopScopeKey, next);
        await _rememberScope(next);
      }
      _shopScopeSeeded = true;
      if (_shopScopeNotifier.value != next) {
        _shopScopeNotifier.value = next;
      }
    } catch (error) {
      debugPrint('[AppCacheManager] setShopScope failed: $error');
    }
  }

  static Future<void> _rememberScope(String scope) async {
    final settings = HiveService.settingsBox;
    final dynamic raw = settings.get(_recentScopesKey);
    final List<String> recent = <String>[
      scope,
      if (raw is List) ...raw.whereType<String>().where((s) => s != scope),
    ].take(_retainedScopeCount).toList(growable: false);
    await settings.put(_recentScopesKey, recent);
    await _pruneScopedEntries(recent.toSet());
  }

  /// Deletes scope-tagged entries whose scope is not in [keep].
  static Future<void> _pruneScopedEntries(Set<String> keep) async {
    for (final Box<dynamic> box in <Box<dynamic>>[
      HiveService.remoteThemeBox,
      HiveService.sectionManifestBox,
      HiveService.bannersBox,
      HiveService.productsBox,
      HiveService.categoriesBox,
    ]) {
      try {
        final List<dynamic> stale = box.keys.where((dynamic key) {
          if (key is! String) {
            return false;
          }
          final String? scope = scopeOfKey(key);
          return scope != null && !keep.contains(scope);
        }).toList(growable: false);
        if (stale.isNotEmpty) {
          await box.deleteAll(stale);
        }
      } catch (error) {
        debugPrint('[AppCacheManager] prune failed: $error');
      }
    }
  }

  /// Clears only user-scoped data caches (cart/wallet/orders/profile/addresses),
  /// plus shop-scoped product/category/theme caches — a different user may
  /// well be allocated to a different store, so the previous user's cached
  /// catalog can't be trusted for them either.
  static Future<void> _clearUserSpecificCaches() async {
    await _safeClearBox(HiveService.ordersBox);
    await clearShopScopedCaches();
    // Cart and wallet are not persisted in their own Hive box (cart lives in
    // backend Redis, wallet is fetched live), but any cached profile/address
    // snapshot and order history must be dropped so the new user starts clean.
    try {
      final settings = HiveService.settingsBox;
      // Drop only cache-meta timestamps; keep auth/onboarding flags.
      // (cacheMetaBox is cleared on version bump; here we just invalidate
      //  user-derived freshness markers so the next read refetches.)
      await settings.delete(StorageKeys.cacheUserProfile);
      await settings.delete(StorageKeys.cacheAddresses);
    } catch (_) {
      // best-effort
    }
  }

  static Future<void> _safeClearBox(Box<dynamic> box) async {
    try {
      await box.clear();
    } catch (error) {
      debugPrint('[AppCacheManager] clear box failed: $error');
    }
  }

}

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/providers/banner_provider.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/providers/home_provider.dart';
import 'package:bakaloo_flutter_app/core/utils/pincode.dart';

/// Refreshes the customer's shop allocation for a specific address, right
/// after that address is saved as (or updated while being) the default.
///
/// Mirrors auth_notifier.dart's `_triggerAllocationAutoAssign` fire-and-forget
/// pattern exactly, but calls `/allocation/recompute` instead of
/// `/allocation/auto-assign` — auto-assign is a no-op once any allocation
/// already exists ("Allocation already exists"), so it never refreshes a
/// customer who changes their delivery address mid-session. Without this,
/// a customer who moves from one store's area to another's keeps seeing the
/// old store's products until they log out and back in.
///
/// Non-fatal by design: the anonymous/unscoped product-visibility fallback
/// keeps the app usable even if this call fails.
Future<void> triggerAllocationRecompute(
  WidgetRef ref, {
  required double lat,
  required double lng,
  required String pincode,
}) async {
  final normalizedPincode = normalizePincode(pincode);
  if (normalizedPincode == null) return;
  try {
    final response = await ref.read(dioClientProvider).post<dynamic>(
      ApiConstants.allocationRecompute,
      data: {
        'address': {
          'lat': lat,
          'lng': lng,
          'pincode': normalizedPincode,
        },
      },
    );
    // Persist the resolved shop scope BEFORE invalidating providers below —
    // see the matching comment in auth_notifier.dart's
    // _triggerAllocationAutoAssign for why ordering matters here.
    await AppCacheManager.applyAllocationResponse(response.data);
    // The home feed / active theme may already be cached from before this
    // address change — refresh them now that the allocation may point to a
    // different store. See auth_notifier.dart's
    // _invalidateShopScopedHomeProviders for why this matters.
    await _invalidateShopScopedHomeProviders(ref);
  } on DioException catch (_) {
    // Non-fatal — refresh interceptor handles 401s; any other failure just
    // leaves the previous allocation in place until the next successful call.
  } catch (_) {
    // Non-fatal — ignore.
  }
}

/// Refreshes the home feeds after the allocation may have changed. Storefront
/// caches/providers are keyed by `StorefrontScope`, so nothing is wiped and the
/// theme/section providers re-key by themselves if the shop changed.
Future<void> _invalidateShopScopedHomeProviders(WidgetRef ref) async {
  try {
    ref.invalidate(homeProvider);
  } catch (_) {}
  try {
    ref.invalidate(homeFeaturedProductsProvider);
  } catch (_) {}
  try {
    ref.invalidate(homeDealsProvider);
  } catch (_) {}
  try {
    ref.invalidate(homeTrendingProductsProvider);
  } catch (_) {}
  try {
    ref.invalidate(homeNewArrivalsProvider);
  } catch (_) {}
  try {
    ref.invalidate(homeCategoryProductsProvider);
  } catch (_) {}
}

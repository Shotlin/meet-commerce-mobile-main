import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';

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
  if (pincode.isEmpty) return;
  try {
    final response = await ref.read(dioClientProvider).post<dynamic>(
      ApiConstants.allocationRecompute,
      data: {
        'address': {
          'lat': lat,
          'lng': lng,
          'pincode': pincode,
        },
      },
    );
    // Committing the resolved shop scope is the whole job. Every storefront
    // provider (theme, tabs, sections, banners, products) is keyed by
    // `StorefrontScope`, so if this address moved the customer to a different
    // shop they all rebuild for it together; if it is the same shop nothing
    // reloads. There is deliberately no manual invalidation list here.
    await AppCacheManager.applyAllocationResponse(response.data);
  } on DioException catch (_) {
    // Non-fatal — refresh interceptor handles 401s; any other failure just
    // leaves the previous allocation in place until the next successful call.
  } catch (_) {
    // Non-fatal — ignore.
  }
}

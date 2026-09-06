import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';

/// Which order-lifecycle events currently notify customers, keyed by
/// timeline type (ORDER_PLACED, CONFIRMED, PREPARING, PACKED,
/// RIDER_ACCEPTED, PICKED_UP, OTP_RESENT, DELIVERED, CANCELLED, REFUNDED) —
/// mirrors the admin's Settings → Order Notifications toggles, so UI that
/// announces an order-status change (the home-screen tracking banner) can
/// stay quiet for the same events the push/in-app notification does,
/// instead of the banner still calling out a status the notification was
/// told to suppress.
///
/// Fetched once per app session and cached — these are admin toggles that
/// change rarely, not something that needs live socket sync. A missing key
/// (fetch failed, or the key predates this feature) means "enabled" —
/// callers should default to `true` when a status isn't present in the map,
/// so a network hiccup here never silently hides a status update the
/// customer should see.
final orderNotificationFlagsProvider = FutureProvider<Map<String, bool>>((ref) async {
  final dio = ref.watch(dioClientProvider);
  try {
    final response = await dio.get<dynamic>('/notifications/event-flags');
    final body = response.data as Map<String, dynamic>?;
    if (body == null || body['success'] != true) {
      return const <String, bool>{};
    }
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) return const <String, bool>{};
    return data.map((key, value) => MapEntry(key, value == true));
  } catch (_) {
    return const <String, bool>{};
  }
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';

/// A single order-lifecycle event's two independent toggles — whether it
/// sends a push/in-app notification, and whether it shows the home-screen
/// tracking banner. These are deliberately separate (an admin can turn one
/// off without the other) — see the dashboard's Order Lifecycle tab.
class OrderNotificationEventFlags {
  const OrderNotificationEventFlags({required this.notification, required this.banner});

  final bool notification;
  final bool banner;
}

/// Which order-lifecycle events currently notify customers and/or show the
/// tracking banner, keyed by timeline type (ORDER_PLACED, CONFIRMED,
/// PREPARING, PACKED, RIDER_ACCEPTED, PICKED_UP, OTP_RESENT, DELIVERED,
/// CANCELLED, REFUNDED) — mirrors the admin dashboard's Order Lifecycle
/// tab, so UI that announces an order-status change (the home-screen
/// tracking banner) can independently stay quiet for an event whose banner
/// was turned off, even if its push notification is still on (or vice
/// versa).
///
/// Fetched once per app session and cached — these are admin toggles that
/// change rarely, not something that needs live socket sync. A missing key
/// (fetch failed, or the key predates this feature) means "enabled" for
/// both — callers should default to `true` when a status isn't present in
/// the map, so a network hiccup here never silently hides a status update
/// the customer should see.
final orderNotificationFlagsProvider = FutureProvider<Map<String, OrderNotificationEventFlags>>((ref) async {
  final dio = ref.watch(dioClientProvider);
  try {
    final response = await dio.get<dynamic>('/notifications/event-flags');
    final body = response.data as Map<String, dynamic>?;
    if (body == null || body['success'] != true) {
      return const <String, OrderNotificationEventFlags>{};
    }
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) return const <String, OrderNotificationEventFlags>{};
    return data.map((key, value) {
      final entry = value as Map<String, dynamic>?;
      return MapEntry(
        key,
        OrderNotificationEventFlags(
          notification: entry?['notification'] != false,
          banner: entry?['banner'] != false,
        ),
      );
    });
  } catch (_) {
    return const <String, OrderNotificationEventFlags>{};
  }
});

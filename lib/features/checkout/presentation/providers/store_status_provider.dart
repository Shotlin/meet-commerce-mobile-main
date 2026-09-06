import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_service.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/store_status_entity.dart';

part 'store_status_provider.g.dart';

/// Broadcast whenever an admin changes the manual override, weekly hours,
/// or the closed-banner image — watching this is what makes
/// [storeStatusProvider] refetch instantly on every screen using it, with
/// no manual pull-to-refresh or app relaunch needed.
final socketStoreStatusUpdateStreamProvider =
    StreamProvider<Map<String, dynamic>>((Ref ref) {
  return ref.watch(socketServiceProvider).storeStatusUpdateStream;
});

/// Single source of truth for "is the storefront open right now" — every
/// widget that needs to gate ASAP ordering or show a "closed" message
/// (cart header, schedule sheet, checkout submit guard, and later the
/// closed-store banner / store-hours sheet) watches this one provider
/// rather than re-fetching independently.
@riverpod
Future<StoreStatusEntity> storeStatus(Ref ref) async {
  // Rebuild the moment the backend broadcasts a change, instead of only
  // refetching on the next natural rebuild (screen reopen, pull-to-refresh).
  ref.watch(socketStoreStatusUpdateStreamProvider);

  final dio = ref.watch(dioClientProvider);
  try {
    final response = await dio.get<dynamic>('/store/status');
    final body = response.data as Map<String, dynamic>?;
    if (body == null || body['success'] != true) {
      return StoreStatusEntity.open();
    }
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) return StoreStatusEntity.open();
    return StoreStatusEntity.fromJson(data);
  } catch (_) {
    // Fail-open client-side too — a network hiccup on this specific call
    // must never block ASAP checkout for everyone else.
    return StoreStatusEntity.open();
  }
}

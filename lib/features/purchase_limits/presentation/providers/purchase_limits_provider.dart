import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';
import 'package:bakaloo_flutter_app/features/purchase_limits/data/datasources/purchase_limits_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/purchase_limits/data/repositories/purchase_limits_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/purchase_limits/domain/entities/purchase_limit_status_entity.dart';
import 'package:bakaloo_flutter_app/features/purchase_limits/domain/repositories/purchase_limits_repository.dart';

part 'purchase_limits_provider.g.dart';

final purchaseLimitsRemoteDataSourceProvider =
    Provider<PurchaseLimitsRemoteDataSource>((Ref ref) {
  return PurchaseLimitsRemoteDataSource(ref.watch(apiClientProvider));
});

final purchaseLimitsRepositoryProvider = Provider<PurchaseLimitsRepository>((
  Ref ref,
) {
  return PurchaseLimitsRepositoryImpl(
    remoteDataSource: ref.watch(purchaseLimitsRemoteDataSourceProvider),
  );
});

// riverpod_generator strips the "Notifier" suffix from the class name when
// deriving the generated provider's constant name (PurchaseLimitsNotifier
// -> purchaseLimitsProvider) — mirrors the exact same situation already
// handled for AuthNotifier/authProvider in auth_notifier.dart (see
// `const authNotifierProvider = authProvider;` there), so every call site
// can use the more descriptive, intention-revealing name instead.
const purchaseLimitsNotifierProvider = purchaseLimitsProvider;

@Riverpod(keepAlive: true)
class PurchaseLimitsNotifier extends _$PurchaseLimitsNotifier {
  @override
  Future<Map<String, PurchaseLimitStatusEntity?>> build() async {
    // Re-evaluated on every auth-state change (mirrors CartNotifier) so
    // purchase-limit data never leaks across a logout / login-as-a-
    // different-customer boundary — a fresh build() always starts from an
    // empty map.
    ref.watch(authStateProvider);
    return const <String, PurchaseLimitStatusEntity?>{};
  }

  /// Fetches purchase-limit status for any [productIds] not already known
  /// (present as a key in the map — either an actual restriction, or a
  /// confirmed-unrestricted `null`) and merges the results into the
  /// existing map rather than replacing it wholesale.
  ///
  /// Safe — and cheap — to call repeatedly with overlapping id lists:
  /// already-known ids are skipped with no network call, so every screen
  /// can call this once per mount with its own visible product ids without
  /// any extra bookkeeping, and without causing redundant refetches when
  /// navigating between screens that share products.
  Future<void> ensureLoaded(List<String> productIds) async {
    if (ref.read(authStateProvider) is! AuthAuthenticated) {
      return;
    }

    final currentMap =
        state.asData?.value ?? const <String, PurchaseLimitStatusEntity?>{};
    final missingIds = <String>{
      for (final rawId in productIds)
        if (rawId.trim().isNotEmpty && !currentMap.containsKey(rawId.trim()))
          rawId.trim(),
    }.toList(growable: false);

    if (missingIds.isEmpty) {
      return;
    }

    final result =
        await ref.read(purchaseLimitsRepositoryProvider).getStatus(
              missingIds,
            );

    result.fold(
      (failure) {
        // Best-effort prefetch for UX only — the backend remains the
        // final authority and will still reject an over-limit mutation
        // even if this client-side cache never populates. Swallow
        // silently so a transient network hiccup never surfaces an error
        // state on a product grid.
      },
      (statuses) {
        final byId = <String, PurchaseLimitStatusEntity>{
          for (final status in statuses) status.productId: status,
        };
        final updated = Map<String, PurchaseLimitStatusEntity?>.from(
          state.asData?.value ?? const <String, PurchaseLimitStatusEntity?>{},
        );
        for (final id in missingIds) {
          // Only restricted products are ever present in the response —
          // an id with no matching entry is confirmed unrestricted (the
          // safe default). Storing an explicit null (rather than leaving
          // the key absent) is what stops ensureLoaded from re-fetching
          // this same already-checked id again on a later call.
          updated[id] = byId[id];
        }
        state = AsyncData(updated);
      },
    );
  }
}

/// O(1) per-product lookup for every "+" button call site. `null` means
/// unrestricted (the safe default) — either genuinely unrestricted, or not
/// yet fetched; either way the UI renders and behaves exactly as it does
/// today.
final purchaseLimitStatusProvider =
    Provider.family<PurchaseLimitStatusEntity?, String>((ref, productId) {
  final map = ref.watch(purchaseLimitsNotifierProvider).asData?.value ??
      const <String, PurchaseLimitStatusEntity?>{};
  return map[productId];
});

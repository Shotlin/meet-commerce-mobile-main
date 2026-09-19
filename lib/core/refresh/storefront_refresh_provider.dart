import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared invalidation signal for dashboard-managed storefront content.
///
/// Screens watch this epoch rather than maintaining disconnected refresh
/// paths. Bumping it makes categories, banners, and category product lists
/// read their live endpoint again; each repository still preserves its local
/// cache solely as an offline fallback.
final storefrontRefreshEpochProvider =
    NotifierProvider<StorefrontRefreshEpochNotifier, int>(
  StorefrontRefreshEpochNotifier.new,
);

class StorefrontRefreshEpochNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() => state++;
}

void refreshStorefrontContent(WidgetRef ref) {
  ref.read(storefrontRefreshEpochProvider.notifier).refresh();
}

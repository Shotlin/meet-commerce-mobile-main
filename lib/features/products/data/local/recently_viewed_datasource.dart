import 'package:hive_flutter/hive_flutter.dart';

import 'package:bakaloo_flutter_app/core/constants/app_constants.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';

class RecentlyViewedDataSource {
  const RecentlyViewedDataSource();

  Future<void> save(String productId) async {
    final normalizedId = productId.trim();
    if (normalizedId.isEmpty) {
      return;
    }

    final box = HiveService.recentlyViewedBox;
    // Keyed by productId itself (unlike search history's hashed query key) —
    // re-viewing a product just overwrites its viewedAt and moves it back
    // to the front, no separate dedup pass needed.
    await box.put(normalizedId, <String, dynamic>{
      'productId': normalizedId,
      'viewedAt': DateTime.now().toIso8601String(),
    });

    final entries = _readEntries(box)
      ..sort((a, b) => b.viewedAt.compareTo(a.viewedAt));

    if (entries.length <= AppConstants.maxRecentlyViewed) {
      return;
    }

    final overflowEntries = entries.skip(AppConstants.maxRecentlyViewed);
    for (final entry in overflowEntries) {
      await box.delete(entry.key);
    }
  }

  /// Product IDs, most-recently-viewed first.
  List<String> getAll() {
    final entries = _readEntries(HiveService.recentlyViewedBox)
      ..sort((a, b) => b.viewedAt.compareTo(a.viewedAt));

    return entries
        .map((entry) => entry.productId)
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Future<void> clearAll() {
    return HiveService.recentlyViewedBox.clear();
  }

  List<_RecentlyViewedEntry> _readEntries(Box<dynamic> box) {
    return box
        .toMap()
        .entries
        .map(
          (entry) =>
              _RecentlyViewedEntry.fromRaw(entry.key.toString(), entry.value),
        )
        .whereType<_RecentlyViewedEntry>()
        .toList();
  }
}

class _RecentlyViewedEntry {
  const _RecentlyViewedEntry({
    required this.key,
    required this.productId,
    required this.viewedAt,
  });

  final String key;
  final String productId;
  final DateTime viewedAt;

  static _RecentlyViewedEntry? fromRaw(String key, dynamic raw) {
    if (raw is! Map) {
      return null;
    }

    final map = Map<String, dynamic>.from(raw);
    final productId = (map['productId'] as String? ?? '').trim();
    final viewedAtRaw = map['viewedAt'];
    final viewedAt = viewedAtRaw is DateTime
        ? viewedAtRaw
        : DateTime.tryParse(viewedAtRaw?.toString() ?? '') ?? DateTime(1970);

    return _RecentlyViewedEntry(
      key: key,
      productId: productId,
      viewedAt: viewedAt,
    );
  }
}

import 'package:bakaloo_flutter_app/core/constants/app_constants.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';

class SearchHistoryDataSource {
  const SearchHistoryDataSource();

  Future<void> save(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return;
    }

    final box = HiveService.searchHistoryBox;
    final key = _hashQuery(normalizedQuery);
    await box.put(key, <String, dynamic>{
      'query': normalizedQuery,
      'searchedAt': DateTime.now().toIso8601String(),
    });

    final entries = box
        .toMap()
        .entries
        .map(
          (entry) => _HistoryEntry.fromRaw(entry.key.toString(), entry.value),
        )
        .whereType<_HistoryEntry>()
        .toList()
      ..sort((a, b) => b.searchedAt.compareTo(a.searchedAt));

    if (entries.length <= AppConstants.maxSearchHistory) {
      return;
    }

    final overflowEntries = entries.skip(AppConstants.maxSearchHistory);
    for (final entry in overflowEntries) {
      await box.delete(entry.key);
    }
  }

  List<String> getAll() {
    final entries = HiveService.searchHistoryBox
        .toMap()
        .entries
        .map(
          (entry) => _HistoryEntry.fromRaw(entry.key.toString(), entry.value),
        )
        .whereType<_HistoryEntry>()
        .toList()
      ..sort((a, b) => b.searchedAt.compareTo(a.searchedAt))
      ..removeWhere((entry) => entry.query.isEmpty);

    return entries.map((entry) => entry.query).toList();
  }

  Future<void> delete(String query) {
    return HiveService.searchHistoryBox.delete(_hashQuery(query));
  }

  Future<void> clearAll() {
    return HiveService.searchHistoryBox.clear();
  }

  String _hashQuery(String query) {
    final normalized = query.trim().toLowerCase();
    var hash = 0x811C9DC5;
    for (final codeUnit in normalized.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class _HistoryEntry {
  const _HistoryEntry({
    required this.key,
    required this.query,
    required this.searchedAt,
  });

  final String key;
  final String query;
  final DateTime searchedAt;

  static _HistoryEntry? fromRaw(String key, dynamic raw) {
    if (raw is! Map) {
      return null;
    }

    final map = Map<String, dynamic>.from(raw);
    final query = (map['query'] as String? ?? '').trim();
    final searchedAtRaw = map['searchedAt'];
    final searchedAt = searchedAtRaw is DateTime
        ? searchedAtRaw
        : DateTime.tryParse(searchedAtRaw?.toString() ?? '') ?? DateTime(1970);

    return _HistoryEntry(
      key: key,
      query: query,
      searchedAt: searchedAt,
    );
  }
}

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/features/search/presentation/providers/search_provider.dart';

part 'search_history_provider.g.dart';

@riverpod
class SearchHistoryNotifier extends _$SearchHistoryNotifier {
  @override
  List<String> build() {
    return ref.read(searchRepositoryProvider).getHistory();
  }

  Future<void> removeQuery(String query) async {
    await ref.read(searchRepositoryProvider).deleteHistory(query);
    state = ref.read(searchRepositoryProvider).getHistory();
  }

  Future<void> clearAll() async {
    await ref.read(clearHistoryUseCaseProvider).call();
    state = const <String>[];
  }

  void refresh() {
    state = ref.read(searchRepositoryProvider).getHistory();
  }
}

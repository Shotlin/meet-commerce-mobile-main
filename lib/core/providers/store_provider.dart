import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/models/store_model.dart';

class _SelectedStoreNotifier extends Notifier<StoreModel> {
  @override
  StoreModel build() => appStores.first;

  void select(StoreModel store) => state = store;
}

class _SelectedCategoryNotifier extends Notifier<String> {
  // '' is a sentinel meaning "no explicit tab picked yet" — consumers
  // resolve it to the store's admin-configured default tab (falling back to
  // 'all', then the first tab) once that store's tabs have loaded. A real
  // tabKey/CategoryModel.id is never empty, so this can't collide.
  @override
  String build() => '';

  void select(String id) {
    // Guard against re-selecting the same tab so providers don't re-fire.
    if (state == id) return;
    state = id;
  }
}

final selectedStoreProvider =
    NotifierProvider<_SelectedStoreNotifier, StoreModel>(
  _SelectedStoreNotifier.new,
);

final selectedCategoryIdProvider =
    NotifierProvider<_SelectedCategoryNotifier, String>(
  _SelectedCategoryNotifier.new,
);

/// A storefront the app can show.
///
/// FreshCuts is a single storefront: the backend `store_key` `zepto` is a
/// persisted identifier (cache keys, dashboard, API), NOT a brand, so it keeps
/// its value. Colours, tabs and layout come exclusively from the Theme Builder
/// (`/theme/tabs`); nothing visual is bundled here.
class StoreModel {
  const StoreModel({required this.id, required this.label});

  /// Backend `store_key`.
  final String id;
  final String label;
}

const List<StoreModel> appStores = <StoreModel>[
  StoreModel(id: 'zepto', label: 'FreshCuts'),
];

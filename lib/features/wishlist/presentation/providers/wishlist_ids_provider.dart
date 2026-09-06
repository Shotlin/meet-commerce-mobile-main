import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/features/wishlist/presentation/providers/wishlist_provider.dart';

part 'wishlist_ids_provider.g.dart';

@riverpod
Set<String> wishlistIds(Ref ref) =>
    ref
        .watch(wishlistProvider)
        .asData
        ?.value
        .items
        .map((e) => e.productId)
        .toSet() ??
    {};

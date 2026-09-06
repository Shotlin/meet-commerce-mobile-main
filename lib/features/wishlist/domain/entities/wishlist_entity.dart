import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';

part 'wishlist_entity.freezed.dart';

@freezed
abstract class WishlistItemEntity with _$WishlistItemEntity {
  const factory WishlistItemEntity({
    required String productId,
    required ProductEntity product,
    DateTime? addedAt,
  }) = _WishlistItemEntity;
}

@freezed
abstract class WishlistEntity with _$WishlistEntity {
  const WishlistEntity._();

  const factory WishlistEntity({
    @Default(<WishlistItemEntity>[]) List<WishlistItemEntity> items,
    @Default(0) int total,
  }) = _WishlistEntity;

  bool get isEmpty => items.isEmpty;
}

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/shared/entities/pagination_entity.dart';

part 'search_result_entity.freezed.dart';

@freezed
abstract class SearchResultEntity with _$SearchResultEntity {
  const factory SearchResultEntity({
    @Default(<ProductEntity>[]) List<ProductEntity> products,
    @Default(<ProductEntity>[]) List<ProductEntity> suggestions,
    @Default(0) int total,
    @Default(
      PaginationEntity(page: 0, limit: 0, total: 0, totalPages: 0),
    )
    PaginationEntity pagination,
  }) = _SearchResultEntity;

  factory SearchResultEntity.empty() => const SearchResultEntity();
}

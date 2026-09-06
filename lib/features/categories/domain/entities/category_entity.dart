import 'package:freezed_annotation/freezed_annotation.dart';

part 'category_entity.freezed.dart';

@freezed
abstract class CategoryEntity with _$CategoryEntity {
  const CategoryEntity._();

  const factory CategoryEntity({
    required String id,
    required String name,
    required int sortOrder,
    required bool isActive,
    required int productCount,
    String? description,
    String? imageUrl,
    String? parentId,
    // A BUNDLE category is a promo-only grouping (e.g. "Milkshake offer")
    // reachable only via a banner deep-link — it must never appear in
    // normal category browsing. Defaults to STANDARD so older cached
    // payloads without this field behave exactly as before.
    @Default('STANDARD') String categoryType,
  }) = _CategoryEntity;

  bool get isParent => parentId == null || parentId!.isEmpty;

  bool get isBundle => categoryType == 'BUNDLE';
}

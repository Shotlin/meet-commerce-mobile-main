import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';

ProductEntity normalizedProductForDetail(ProductEntity product) {
  final netQuantity = (product.netQuantity ?? '').trim().isNotEmpty
      ? product.netQuantity!.trim()
      : product.unit;
  return product.copyWith(netQuantity: netQuantity);
}

/// Builds the "Product Details" attribute grid from every source the
/// dashboard lets an admin fill in independently — generic attributes,
/// ingredients, storage instructions, and nutrition info are all separate
/// editable fields (see ProductForm.tsx), not alternatives to each other.
/// Previously this returned `product.attributes` alone whenever it was
/// non-empty, silently discarding nutrition/ingredients/storage the same
/// admin had also set — merging them fixes that.
///
/// Description is deliberately never folded in here: ProductDetailScreen
/// already renders it via its own ProductDescriptionSection whenever it's
/// non-empty, so adding it as a synthetic attribute too just duplicated it
/// on screen.
List<Map<String, dynamic>> effectiveAttributesForDetail(ProductEntity product) {
  final attrs = <Map<String, dynamic>>[];

  if (product.hasAttributes) {
    attrs.addAll(product.attributes!);
  }
  if ((product.ingredients ?? '').trim().isNotEmpty) {
    attrs.add(<String, dynamic>{
      'label': 'Ingredients',
      'value': product.ingredients!,
    });
  }
  if ((product.storageInstructions ?? '').trim().isNotEmpty) {
    attrs.add(<String, dynamic>{
      'label': 'Storage Instructions',
      'value': product.storageInstructions!,
    });
  }
  if ((product.nutritionInfo ?? const <String, dynamic>{}).isNotEmpty) {
    for (final entry in product.nutritionInfo!.entries) {
      attrs.add(<String, dynamic>{
        'label': entry.key,
        'value': '${entry.value}',
      });
    }
  }
  return attrs;
}

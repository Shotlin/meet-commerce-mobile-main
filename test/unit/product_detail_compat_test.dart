import 'package:flutter_test/flutter_test.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/screens/product_detail_compat.dart';

/// Map literals aren't `==`-equal by content in Dart, so `contains()` can't
/// be used directly against a List<Map> — check by field instead.
bool _hasAttr(List<Map<String, dynamic>> attrs, String label, String value) {
  return attrs.any((a) => a['label'] == label && a['value'] == value);
}

void main() {
  ProductEntity makeProduct({
    String? description,
    String? ingredients,
    String? storageInstructions,
    Map<String, dynamic>? nutritionInfo,
    List<Map<String, dynamic>>? attributes,
  }) {
    return ProductEntity(
      id: 'test-id',
      name: 'Test Product',
      slug: 'test-product',
      price: 100,
      stockQuantity: 10,
      unit: 'piece',
      images: const [],
      tags: const [],
      isFeatured: false,
      isActive: true,
      totalSold: 0,
      description: description,
      ingredients: ingredients,
      storageInstructions: storageInstructions,
      nutritionInfo: nutritionInfo,
      attributes: attributes,
      foodType: 'NONE',
      originTag: 'NONE',
      optionCount: 1,
      avgRating: 0,
      ratingCount: 0,
      customBadges: const [],
    );
  }

  group('effectiveAttributesForDetail', () {
    test('merges generic attributes with nutrition instead of dropping nutrition', () {
      final product = makeProduct(
        attributes: [
          {'label': 'Brand', 'value': 'Amul'},
        ],
        nutritionInfo: {'Energy': '52 kcal', 'Protein': '0.3g'},
      );

      final result = effectiveAttributesForDetail(product);

      expect(_hasAttr(result, 'Brand', 'Amul'), isTrue);
      expect(_hasAttr(result, 'Energy', '52 kcal'), isTrue);
      expect(_hasAttr(result, 'Protein', '0.3g'), isTrue);
    });

    test('merges generic attributes with ingredients and storage instructions', () {
      final product = makeProduct(
        attributes: [
          {'label': 'Weight', 'value': '250g'},
        ],
        ingredients: 'Milk, Sugar',
        storageInstructions: 'Keep refrigerated',
      );

      final result = effectiveAttributesForDetail(product);

      expect(_hasAttr(result, 'Weight', '250g'), isTrue);
      expect(_hasAttr(result, 'Ingredients', 'Milk, Sugar'), isTrue);
      expect(_hasAttr(result, 'Storage Instructions', 'Keep refrigerated'), isTrue);
    });

    test('never includes description as a synthetic attribute — it has its own dedicated section', () {
      final product = makeProduct(description: 'A great product to buy.');

      final result = effectiveAttributesForDetail(product);

      expect(result, isEmpty);
      expect(result.any((a) => a['label'] == 'Description'), isFalse);
    });

    test('returns an empty list when nothing is set at all', () {
      final product = makeProduct();
      expect(effectiveAttributesForDetail(product), isEmpty);
    });

    test('nutrition alone (no generic attributes) still shows', () {
      final product = makeProduct(nutritionInfo: {'Calories': '100'});
      final result = effectiveAttributesForDetail(product);
      expect(_hasAttr(result, 'Calories', '100'), isTrue);
    });
  });
}

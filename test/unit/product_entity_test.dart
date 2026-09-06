import 'package:flutter_test/flutter_test.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';

void main() {
  ProductEntity makeProduct({
    String foodType = 'NONE',
    String originTag = 'NONE',
    int optionCount = 1,
    String? optionLabel,
    String? netQuantity,
    String unit = 'piece',
    double price = 100,
    double? salePrice,
    int? displayDeliveryMinutes,
    double avgRating = 0,
    int ratingCount = 0,
    List<String> customBadges = const [],
    String? productFamilyId,
  }) {
    return ProductEntity(
      id: 'test-id',
      name: 'Test Product',
      slug: 'test-product',
      price: price,
      stockQuantity: 10,
      unit: unit,
      images: const [],
      tags: const [],
      isFeatured: false,
      isActive: true,
      totalSold: 0,
      salePrice: salePrice,
      foodType: foodType,
      originTag: originTag,
      optionCount: optionCount,
      optionLabel: optionLabel,
      netQuantity: netQuantity,
      displayDeliveryMinutes: displayDeliveryMinutes,
      avgRating: avgRating,
      ratingCount: ratingCount,
      customBadges: customBadges,
      productFamilyId: productFamilyId,
    );
  }

  group('ProductEntity option getters', () {
    test('hasMultipleOptions is true when optionCount > 1', () {
      expect(makeProduct(optionCount: 3).hasMultipleOptions, isTrue);
    });

    test('hasMultipleOptions is false when optionCount == 1', () {
      expect(makeProduct(optionCount: 1).hasMultipleOptions, isFalse);
    });

    test('hasMultipleOptions is false with default optionCount', () {
      expect(makeProduct().hasMultipleOptions, isFalse);
    });
  });

  group('ProductEntity food type getters', () {
    test('isVeg returns true for VEG', () {
      expect(makeProduct(foodType: 'VEG').isVeg, isTrue);
    });

    test('isNonVeg returns true for NON_VEG', () {
      expect(makeProduct(foodType: 'NON_VEG').isNonVeg, isTrue);
    });

    test('isEgg returns true for EGG', () {
      expect(makeProduct(foodType: 'EGG').isEgg, isTrue);
    });

    test('hasFoodMarker is false for NONE', () {
      expect(makeProduct(foodType: 'NONE').hasFoodMarker, isFalse);
    });

    test('hasFoodMarker is true for VEG', () {
      expect(makeProduct(foodType: 'VEG').hasFoodMarker, isTrue);
    });
  });

  group('ProductEntity origin tag getters', () {
    test('isImported returns true for IMPORTED', () {
      expect(makeProduct(originTag: 'IMPORTED').isImported, isTrue);
    });

    test('isLocal returns true for LOCAL', () {
      expect(makeProduct(originTag: 'LOCAL').isLocal, isTrue);
    });

    test('hasOriginTag is false for NONE', () {
      expect(makeProduct(originTag: 'NONE').hasOriginTag, isFalse);
    });
  });

  group('ProductEntity displayUnit priority', () {
    test('prefers optionLabel over netQuantity and unit', () {
      final p = makeProduct(
        optionLabel: '500g',
        netQuantity: '500 grams',
        unit: 'g',
      );
      expect(p.displayUnit, '500g');
    });

    test('falls back to netQuantity when optionLabel is null', () {
      final p = makeProduct(
        optionLabel: null,
        netQuantity: '1 kg',
        unit: 'kg',
      );
      expect(p.displayUnit, '1 kg');
    });

    test('falls back to unit when both are null', () {
      final p = makeProduct(
        optionLabel: null,
        netQuantity: null,
        unit: 'piece',
      );
      expect(p.displayUnit, 'piece');
    });
  });

  group('ProductEntity discount getters', () {
    test('discountPercent calculates correctly', () {
      final p = makeProduct(price: 100, salePrice: 80);
      expect(p.discountPercent, 20);
    });

    test('discountAmount calculates correctly', () {
      final p = makeProduct(price: 100, salePrice: 75);
      expect(p.discountAmount, 25.0);
    });

    test('discountPercent is 0 when no sale', () {
      expect(makeProduct(price: 100).discountPercent, 0);
    });

    test('discountAmount is 0 when salePrice >= price', () {
      final p = makeProduct(price: 100, salePrice: 120);
      expect(p.discountAmount, 0);
    });
  });

  group('ProductEntity delivery time', () {
    test('hasDeliveryTime is true when set', () {
      expect(makeProduct(displayDeliveryMinutes: 10).hasDeliveryTime, isTrue);
    });

    test('hasDeliveryTime is false when null', () {
      expect(makeProduct().hasDeliveryTime, isFalse);
    });

    test('formattedDeliveryTime returns correct string', () {
      expect(
        makeProduct(displayDeliveryMinutes: 15).formattedDeliveryTime,
        '15 mins',
      );
    });

    test('formattedDeliveryTime is empty when null', () {
      expect(makeProduct().formattedDeliveryTime, '');
    });
  });

  group('ProductEntity rating', () {
    test('hasRating is true when avgRating > 0 and ratingCount > 0', () {
      expect(makeProduct(avgRating: 4.2, ratingCount: 100).hasRating, isTrue);
    });

    test('hasRating is false when avgRating is 0', () {
      expect(makeProduct(avgRating: 0, ratingCount: 50).hasRating, isFalse);
    });

    test('formattedRating formats correctly with k suffix', () {
      final p = makeProduct(avgRating: 4.5, ratingCount: 1200);
      expect(p.formattedRating, '4.5 ★ 1.2k');
    });

    test('formattedRating formats correctly without k suffix', () {
      final p = makeProduct(avgRating: 3.8, ratingCount: 42);
      expect(p.formattedRating, '3.8 ★ 42');
    });
  });

  group('ProductEntity badges', () {
    test('hasBadges is true when customBadges is not empty', () {
      expect(makeProduct(customBadges: ['Bestseller']).hasBadges, isTrue);
    });

    test('hasBadges is false when customBadges is empty', () {
      expect(makeProduct(customBadges: []).hasBadges, isFalse);
    });
  });
}

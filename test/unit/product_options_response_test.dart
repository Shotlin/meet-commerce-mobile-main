import 'package:flutter_test/flutter_test.dart';
import 'package:bakaloo_flutter_app/features/products/data/models/product_options_response.dart';

void main() {
  group('ProductOptionsResponse.fromJson', () {
    test('parses valid response with family and options', () {
      final json = <String, dynamic>{
        'family': {
          'id': 'fam-1',
          'name': 'Tomato',
          'slug': 'tomato',
          'thumbnailUrl': 'https://example.com/tomato.jpg',
        },
        'options': [
          {
            'id': 'opt-1',
            'shopProductId': 'sp-1',
            'shopId': 'shop-1',
            'name': 'Tomato 500g',
            'optionLabel': '500g',
            'unit': 'g',
            'price': 25.0,
            'salePrice': 20.0,
            'stockQuantity': 30,
            'maxOrderQty': 10,
            'isAvailable': true,
            'foodType': 'VEG',
            'originTag': 'LOCAL',
            'customBadges': ['Fresh'],
            'avgRating': 4.2,
            'ratingCount': 156,
            'displayDeliveryMinutes': 10,
          },
          {
            'id': 'opt-2',
            'name': 'Tomato 1kg',
            'optionLabel': '1kg',
            'unit': 'kg',
            'price': 45.0,
            'isAvailable': true,
          },
        ],
      };

      final response = ProductOptionsResponse.fromJson(json);
      expect(response.family, isNotNull);
      expect(response.family!.name, 'Tomato');
      expect(response.options.length, 2);

      final opt1 = response.options[0];
      expect(opt1.id, 'opt-1');
      expect(opt1.shopProductId, 'sp-1');
      expect(opt1.effectivePrice, 20.0);
      expect(opt1.discountPercent, 20);
      expect(opt1.inStock, isTrue);
      expect(opt1.isVeg, isTrue);
      expect(opt1.displayUnit, '500g');
    });

    test('parses response with null family', () {
      final json = <String, dynamic>{
        'family': null,
        'options': [
          {
            'id': 'single-1',
            'name': 'Single Product',
            'unit': 'piece',
            'price': 50,
            'isAvailable': true,
          },
        ],
      };

      final response = ProductOptionsResponse.fromJson(json);
      expect(response.family, isNull);
      expect(response.options.length, 1);
    });

    test('handles empty options list', () {
      final json = <String, dynamic>{
        'family': {'id': 'fam-1', 'name': 'Empty'},
        'options': <dynamic>[],
      };

      final response = ProductOptionsResponse.fromJson(json);
      expect(response.options, isEmpty);
    });

    test('handles missing optional fields gracefully', () {
      final json = <String, dynamic>{
        'options': [
          {
            'id': 'opt-minimal',
            'name': 'Minimal',
            'unit': 'piece',
            'price': 10,
            'isAvailable': false,
          },
        ],
      };

      final response = ProductOptionsResponse.fromJson(json);
      final opt = response.options[0];
      expect(opt.shopProductId, isNull);
      expect(opt.salePrice, isNull);
      expect(opt.foodType, 'NONE');
      expect(opt.customBadges, isEmpty);
      expect(opt.inStock, isFalse);
    });
  });

  group('ProductOptionItem.inStock', () {
    test('true when available and stock > 0', () {
      final opt = ProductOptionItem.fromJson({
        'id': '1', 'name': 'T', 'unit': 'g', 'price': 10,
        'isAvailable': true, 'stockQuantity': 5,
      });
      expect(opt.inStock, isTrue);
    });

    test('false when not available', () {
      final opt = ProductOptionItem.fromJson({
        'id': '1', 'name': 'T', 'unit': 'g', 'price': 10,
        'isAvailable': false, 'stockQuantity': 5,
      });
      expect(opt.inStock, isFalse);
    });

    test('false when stock is 0', () {
      final opt = ProductOptionItem.fromJson({
        'id': '1', 'name': 'T', 'unit': 'g', 'price': 10,
        'isAvailable': true, 'stockQuantity': 0,
      });
      expect(opt.inStock, isFalse);
    });

    test('true when stockQuantity is null (unknown stock)', () {
      final opt = ProductOptionItem.fromJson({
        'id': '1', 'name': 'T', 'unit': 'g', 'price': 10,
        'isAvailable': true,
      });
      expect(opt.inStock, isTrue);
    });
  });
}

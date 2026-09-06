import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_item_entity.dart';

class OrderItemModel {
  const OrderItemModel({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.unit,
    required this.total,
    this.thumbnailUrl,
  });

  final String productId;
  final String name;
  final double price;
  final int quantity;
  final String unit;
  final double total;
  final String? thumbnailUrl;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      productId: _readString(
        json,
        <String>['productId', 'product_id', 'id'],
      ),
      name: _readString(json, <String>['name'], fallback: 'Item'),
      price: _readDouble(json, <String>['price', 'salePrice', 'sale_price']),
      quantity: _readInt(json, <String>['quantity', 'qty'], fallback: 1),
      unit: _readString(json, <String>['unit'], fallback: 'pc'),
      total: _readDouble(json, <String>['total', 'lineTotal', 'line_total']),
      thumbnailUrl: _readNullableString(
        json,
        <String>['thumbnailUrl', 'thumbnail_url', 'imageUrl', 'image_url'],
      ),
    );
  }

  OrderItemEntity toEntity() {
    return OrderItemEntity(
      productId: productId,
      name: name,
      price: price,
      quantity: quantity,
      unit: unit,
      total: total,
      thumbnailUrl: thumbnailUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'productId': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'unit': unit,
      'total': total,
      'thumbnailUrl': thumbnailUrl,
    };
  }

  static String _readString(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return fallback;
  }

  static String? _readNullableString(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static double _readDouble(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String && value.trim().isNotEmpty) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return 0;
  }

  static int _readInt(
    Map<String, dynamic> json,
    List<String> keys, {
    int fallback = 0,
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String && value.trim().isNotEmpty) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return fallback;
  }
}

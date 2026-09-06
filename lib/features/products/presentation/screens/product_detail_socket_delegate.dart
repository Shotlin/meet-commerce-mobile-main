import 'package:flutter/foundation.dart';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/socket/socket_service.dart';

class ProductDetailSocketDelegate {
  ProductDetailSocketDelegate({
    required this.ref,
    required this.productId,
    required this.onProductDataChanged,
    required this.onCartChanged,
  });

  final WidgetRef ref;
  final String productId;
  final VoidCallback onProductDataChanged;
  final VoidCallback onCartChanged;

  void setup() {
    ref.read(socketServiceProvider)
      ..on('product:stock_update', _handleStockUpdate)
      ..on('product:price_update', _handlePriceUpdate)
      ..on('cart:updated', _handleCartUpdate);
  }

  void dispose() {
    ref.read(socketServiceProvider)
      ..off('product:stock_update', _handleStockUpdate)
      ..off('product:price_update', _handlePriceUpdate)
      ..off('cart:updated', _handleCartUpdate);
  }

  void _handleStockUpdate(dynamic data) {
    if (_shouldRefreshProductData(data)) {
      onProductDataChanged();
    }
  }

  void _handlePriceUpdate(dynamic data) {
    if (_shouldRefreshProductData(data)) {
      onProductDataChanged();
    }
  }

  void _handleCartUpdate(dynamic _) {
    onCartChanged();
  }

  bool _shouldRefreshProductData(dynamic payload) {
    final json = _asMap(payload);
    if (json == null || json.isEmpty) {
      return true;
    }

    final nested = json['product'];
    final nestedId = nested is Map ? nested['id']?.toString() : null;
    final ids = <String>{
      json['productId']?.toString() ?? '',
      json['product_id']?.toString() ?? '',
      json['id']?.toString() ?? '',
      nestedId ?? '',
    }..remove('');

    return ids.isEmpty || ids.contains(productId);
  }

  Map<String, dynamic>? _asMap(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    if (payload is String && payload.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

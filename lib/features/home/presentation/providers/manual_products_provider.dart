import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/features/products/data/models/product_model.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';

/// Fetches a list of specific product IDs directly from the API.
///
/// Fallback for manual-source product grids when the section manifest did not
/// already carry server-resolved products (e.g. a stale cached manifest saved
/// before the backend embedded `products`). Hand-picked products may live in
/// categories not loaded on the home feed, so we fetch them by id.
///
/// The family key is an order-preserving comma-joined string of the ids — NOT
/// the raw `List<String>`. Riverpod `.family` compares keys with `==`, and Dart
/// lists use identity equality, so a `List` key created a brand-new (uncached)
/// `autoDispose` provider on every widget build; the fetch never settled and
/// hand-picked products silently failed to load. A `String` key caches stably.
final manualProductsByIdsProvider = FutureProvider.autoDispose
    .family<List<ProductEntity>, String>(
  (ref, idsCsv) async {
    final ids = idsCsv
        .split(',')
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toList(growable: false);
    if (ids.isEmpty) return const <ProductEntity>[];

    final dio = ref.watch(dioClientProvider);

    // Fetch all IDs concurrently. The Dio base URL already includes `/api/v1`,
    // so the path must be `/products/$id` (not `/api/v1/products/$id`).
    final futures = ids.map((id) async {
      try {
        final response = await dio.get<dynamic>('/products/$id');
        final body = response.data;
        if (body is! Map) return null;
        final data = body['data'];
        if (data is! Map) return null;
        return ProductModel.fromJson(
          Map<String, dynamic>.from(data),
        ).toEntity();
      } catch (_) {
        return null; // skip failed individual fetches
      }
    });

    final results = await Future.wait(futures);
    return results.whereType<ProductEntity>().toList();
  },
);

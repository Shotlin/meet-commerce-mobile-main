import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/features/products/data/models/product_options_response.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/providers/product_list_provider.dart';

part 'product_options_provider.g.dart';

@riverpod
Future<ProductOptionsResponse> productOptions(Ref ref, String productId) async {
  // Family chips remain hot while the user changes tabs or selects another
  // size, so the compact card never flashes empty during a repeat fetch.
  ref.keepAlive();
  final datasource = ref.watch(productRemoteDataSourceProvider);
  final response = await datasource.getProductOptions(productId);
  return response;
}

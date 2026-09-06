import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/features/products/data/models/product_options_response.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/providers/product_list_provider.dart';

part 'product_options_provider.g.dart';

@riverpod
Future<ProductOptionsResponse> productOptions(Ref ref, String productId) async {
  final datasource = ref.watch(productRemoteDataSourceProvider);
  final response = await datasource.getProductOptions(productId);
  return response;
}

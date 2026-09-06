import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/features/categories/domain/entities/category_entity.dart';
import 'package:bakaloo_flutter_app/features/categories/presentation/providers/category_provider.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/screens/product_list_screen.dart';

class CategoryProductsScreen extends ConsumerWidget {
  const CategoryProductsScreen({
    required this.id,
    super.key,
  });

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryCollectionProvider).asData?.value ??
        const <CategoryEntity>[];
    CategoryEntity? category;
    for (final item in categories) {
      if (item.id == id) {
        category = item;
        break;
      }
    }

    return ProductListScreen(
      categoryId: id,
      title: category?.name ?? 'Category products',
    );
  }
}

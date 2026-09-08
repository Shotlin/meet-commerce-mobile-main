import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/purchase_limits/presentation/providers/purchase_limits_provider.dart';
import 'package:bakaloo_flutter_app/shared/widgets/product_card.dart';

void main() {
  const product = ProductEntity(
    id: 'fresh',
    name: 'Chicken Curry Cut — Bachelors Pack',
    slug: 'fresh',
    price: 165,
    salePrice: 129,
    stockQuantity: 10,
    unit: '350 g',
    images: [],
    tags: [],
    isFeatured: true,
    isActive: true,
    totalSold: 0,
    description: 'Juicy, bone-in pieces for everyday curries.',
    highlights: {'pieces': '6–10', 'serves': '2'},
    displayDeliveryMinutes: 30,
  );
  Future<void> mount(WidgetTester tester,
      {double width = 350,
      double scale = 1,
      bool rail = false,
      int quantity = 0,
      VoidCallback? options,}) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          cartItemQuantityProvider('fresh').overrideWith((ref) => quantity),
          purchaseLimitStatusProvider('fresh').overrideWith((ref) => null),
        ],
        child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (context, child) => MaterialApp(
                    home: Scaffold(
                  body: MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: SingleChildScrollView(
                          child: ProductCard(
                        product: options == null
                            ? product
                            : product.copyWith(optionCount: 2),
                        width: width,
                        style: rail
                            ? ProductCardStyle.scroll
                            : ProductCardStyle.grid,
                        variant: ProductCardVariant.premiumFresh,
                        onOptionsTap: options,
                      ),),),
                ),),),),);
    await tester.pump();
  }

  for (final width in [155.0, 350.0]) {
    testWidgets('premium card fits width $width with enlarged text',
        (tester) async {
      addTearDown(tester.view.reset);
      await mount(tester, width: width, scale: 1.5);
      expect(tester.takeException(), isNull);
      expect(find.text('₹129'), findsOneWidget);
      expect(find.text('22% off'), findsOneWidget);
      expect(find.text('350 g | 6–10 pieces | Serves 2'), findsOneWidget);
      expect(find.text('30 mins'), findsOneWidget);
    });
  }
  testWidgets('rail keeps details under the photo and quantity control',
      (tester) async {
    addTearDown(tester.view.reset);
    await mount(tester, width: 240, rail: true, quantity: 2);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('₹129'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('premium add opens options for a product family', (tester) async {
    addTearDown(tester.view.reset);
    var opened = false;
    await mount(tester, options: () => opened = true);
    await tester.tap(find.text('Add +'));
    await tester.pump();
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });
}

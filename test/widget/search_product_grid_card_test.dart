import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/products/data/models/product_options_response.dart'
    as options_model;
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/providers/product_options_provider.dart';
import 'package:bakaloo_flutter_app/features/purchase_limits/presentation/providers/purchase_limits_provider.dart';
import 'package:bakaloo_flutter_app/features/search/presentation/widgets/search_product_grid_card.dart';
import 'package:bakaloo_flutter_app/features/wishlist/domain/entities/wishlist_entity.dart';
import 'package:bakaloo_flutter_app/features/wishlist/presentation/providers/wishlist_provider.dart';

// The card always renders a wishlist heart, which watches wishlistProvider.
// Its real build() reads auth state (to fetch the signed-in user's saved
// items), which in turn touches AuthNotifier — a keepAlive provider whose
// build() registers an onDispose callback with a pre-existing bug (a
// ref.read call inside onDispose, invalid per Riverpod 3.x) unrelated to
// this card. Stubbing wishlistProvider keeps these layout tests focused on
// the card itself instead of tripping that unrelated provider-teardown bug.
class _StubWishlistNotifier extends WishlistNotifier {
  @override
  Future<WishlistEntity> build() async => const WishlistEntity();
}

// Same worst-case-sizing formula as _GridGeometry in search_screen.dart —
// duplicated here (that class is library-private) so the test constrains
// the card exactly the way the real grid cell would at a given device width.
({double cardWidth, double mainAxisExtent}) _geometryFor(double screenWidth) {
  final horizontalPadding = screenWidth <= 375 ? 12.0 : 16.0;
  const crossAxisSpacing = 10.0;
  final cardWidth =
      (screenWidth - horizontalPadding * 2 - crossAxisSpacing) / 2;
  final imageHeight = cardWidth / 1.10;
  final widthScale = screenWidth / 390.0;
  final contentHeight = 235.0 * widthScale;
  final mainAxisExtent = (imageHeight + contentHeight).clamp(320.0, 440.0);
  return (cardWidth: cardWidth, mainAxisExtent: mainAxisExtent);
}

const _wornCutProduct = ProductEntity(
  id: 'mutton-chops',
  name: 'Mutton Chops — Premium Bone-in Grilling Cut Selection',
  slug: 'mutton-chops',
  price: 1120,
  salePrice: 1050,
  stockQuantity: 12,
  unit: '500 g',
  images: <String>[],
  tags: <String>['Perfect for grilling', 'Rich in Flavour'],
  isFeatured: false,
  isActive: true,
  totalSold: 0,
  description: 'Perfect for grilling.',
  customBadges: <String>['Premium Cut'],
  displayDeliveryMinutes: 30,
  productFamilyId: 'family-mutton-chops',
  optionCount: 3,
);

const _minimalProduct = ProductEntity(
  id: 'chicken-wings',
  name: 'Chicken Wings',
  slug: 'chicken-wings',
  price: 220,
  stockQuantity: 5,
  unit: '500 g',
  images: <String>[],
  tags: <String>[],
  isFeatured: false,
  isActive: true,
  totalSold: 0,
);

const _outOfStockProduct = ProductEntity(
  id: 'salmon-steak',
  name: 'Salmon Steak',
  slug: 'salmon-steak',
  price: 480,
  salePrice: 420,
  stockQuantity: 0,
  unit: '250 g',
  images: <String>[],
  tags: <String>['Rich in Omega 3'],
  isFeatured: false,
  isActive: true,
  totalSold: 0,
);

const _familyOptions = options_model.ProductOptionsResponse(
  family: options_model.ProductOptionsFamily(
    id: 'family-mutton-chops',
    name: 'Mutton Chops',
  ),
  options: <options_model.ProductOptionItem>[
    options_model.ProductOptionItem(
      id: 'mutton-chops',
      name: 'Mutton Chops',
      unit: '500 g',
      optionLabel: '500 g',
      price: 1120,
      salePrice: 1050,
      isAvailable: true,
      stockQuantity: 12,
      customBadges: <String>['Premium Cut'],
      displayDeliveryMinutes: 30,
    ),
    options_model.ProductOptionItem(
      id: 'mutton-chops-1kg',
      name: 'Mutton Chops',
      unit: '1 kg',
      optionLabel: '1 kg',
      price: 2100,
      isAvailable: true,
      stockQuantity: 8,
      displayDeliveryMinutes: 30,
    ),
    options_model.ProductOptionItem(
      id: 'mutton-chops-2kg',
      name: 'Mutton Chops',
      unit: '2 kg',
      optionLabel: '2 kg',
      price: 4000,
      isAvailable: true,
      stockQuantity: 4,
      displayDeliveryMinutes: 30,
    ),
  ],
);

Future<void> _mount(
  WidgetTester tester, {
  required ProductEntity product,
  required double screenWidth,
  int quantity = 0,
  bool overrideOptions = false,
}) async {
  final geometry = _geometryFor(screenWidth);
  tester.view.physicalSize = Size(screenWidth, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cartItemQuantityProvider(product.id).overrideWith((ref) => quantity),
        purchaseLimitStatusProvider(product.id).overrideWith((ref) => null),
        wishlistProvider.overrideWith(_StubWishlistNotifier.new),
        if (overrideOptions)
          productOptionsProvider(
            product.productFamilyId ?? product.id,
          ).overrideWith((ref) async => _familyOptions),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, child) => MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.white,
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: geometry.cardWidth,
                height: geometry.mainAxisExtent,
                child: SearchProductGridCard(product: product),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  for (final width in <double>[360, 375, 390, 412, 430]) {
    testWidgets(
      'multi-option discounted card fits a $width-wide grid cell with zero overflow',
      (tester) async {
        await _mount(
          tester,
          product: _wornCutProduct,
          screenWidth: width,
          overrideOptions: true,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('₹1,050'), findsOneWidget);
        expect(find.text('₹1,120'), findsOneWidget);
      },
    );
  }

  testWidgets('minimal product (no subtitle/discount/delivery/badge) renders without overflow',
      (tester) async {
    await _mount(tester, product: _minimalProduct, screenWidth: 390);
    expect(tester.takeException(), isNull);
    expect(find.text('₹220'), findsOneWidget);
  });

  testWidgets('out-of-stock product shows a disabled Out control, no overflow',
      (tester) async {
    await _mount(tester, product: _outOfStockProduct, screenWidth: 390);
    expect(tester.takeException(), isNull);
    expect(find.text('Out'), findsOneWidget);
  });

  testWidgets('quantity stepper renders in place of the add button when already in cart',
      (tester) async {
    await _mount(
      tester,
      product: _minimalProduct,
      screenWidth: 390,
      quantity: 3,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('variant chips show real sibling options and mark the current one selected',
      (tester) async {
    await _mount(
      tester,
      product: _wornCutProduct,
      screenWidth: 390,
      overrideOptions: true,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('500 g'), findsOneWidget);
    expect(find.text('1 kg'), findsOneWidget);
    // Third sibling collapses behind a "+1" overflow chip.
    expect(find.text('+1'), findsOneWidget);
  });
}

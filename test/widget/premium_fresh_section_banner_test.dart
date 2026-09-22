// "Premium Fresh — Product Slider" (product_carousel) and "Premium Fresh —
// Product Grid" (category_product_grid): the uploaded section_header graphic
// must sit flush against the top of a configurable premium container — 0 gap
// above it, full width, only the container's top-left/top-right corners
// rounded — instead of floating as a small centered image with white space
// around it. Every other section_header consumer (round_category_icons) must
// keep its original floating-card treatment untouched.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_model.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/widgets/section_registry.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';

const String kBannerUrl = 'https://cdn.test/premium-banner.png';

/// Real `AuthNotifier.build()` registers `ref.onDispose(() =>
/// ref.read(socketServiceProvider).disconnect())`, which trips Riverpod's
/// "cannot read another provider mid-teardown" guard when a whole
/// `ProviderScope` (as in a widget test) is disposed at once rather than one
/// provider at a time. Unrelated to this fix — swapped out so mounting a
/// real section through `sectionRegistry` doesn't drag in the app's full
/// socket/auth lifecycle just to check container/banner layout.
class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthUnauthenticated();
}

Map<String, dynamic> _product(String id) => <String, dynamic>{
      'id': id,
      'name': 'Product $id',
      'slug': id,
      'price': 199,
      'stock_quantity': 10,
      'unit': '500 g',
    };

SectionManifestEntry _entry({
  required SectionType type,
  required Map<String, dynamic> config,
  String? productCardStyle,
}) {
  return SectionManifestEntry.fromJson(<String, dynamic>{
    'id': 'sec-1',
    'type': type.value,
    'order': 0,
    'visible': true,
    'config': <String, dynamic>{
      if (productCardStyle != null) 'product_card_style': productCardStyle,
      ...config,
    },
    'products': <Map<String, dynamic>>[_product('p1'), _product('p2')],
  });
}

Future<void> _mount(
  WidgetTester tester,
  SectionManifestEntry entry, {
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(_FakeAuthNotifier.new),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Consumer(
                builder: (context, ref, _) => sectionRegistry[entry.type]!(
                  entry,
                  RemoteTheme.neutral(),
                  ref,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // AppImage's network fetch always fails in the test harness (no real
  // network) — settle onto its errorWidget instead of pumping forever.
  await tester.pump(const Duration(milliseconds: 50));
}

/// The banner image is identified by URL, not by widget type — `AspectRatio`
/// and `Container` also appear inside `ProductCard` below it, so a type-only
/// finder would match those too.
Finder _bannerImage() => find.byWidgetPredicate(
      (w) => w is AppImage && w.imageUrl == kBannerUrl,
    );

/// The premium wrapper `Container` is identified by its decoration (a
/// `BoxDecoration` with only top corners rounded), not by type — `Container`
/// also appears throughout `ProductCard`.
Finder _premiumContainer() => find.byWidgetPredicate((w) {
      if (w is! Container || w.decoration is! BoxDecoration) return false;
      final decoration = w.decoration! as BoxDecoration;
      final radius = decoration.borderRadius;
      return radius is BorderRadius &&
          radius.bottomLeft == Radius.zero &&
          radius.bottomRight == Radius.zero;
    });

/// Every `Padding` ancestor of the banner that represents an actual
/// MARGIN-like inset around it, as opposed to structural insets Flutter's own
/// `Container` widget always interposes between its `DecoratedBox` and child:
/// a bare `EdgeInsets.zero` (no border configured) and a uniform
/// `EdgeInsets.all(borderWidth)` (`BoxDecoration.padding` insets the child by
/// exactly the border's stroke width so it isn't drawn under/over it) both
/// come from `Container` itself, not from a floating-card style margin — the
/// one thing this fix actually removes for a flush banner.
List<Padding> _nonZeroPaddingAncestors(
  WidgetTester tester,
  Finder of, {
  double allowedBorderWidth = 0,
}) {
  final paddings = tester.widgetList<Padding>(
    find.ancestor(of: of, matching: find.byType(Padding)),
  );
  final borderInset = EdgeInsets.all(allowedBorderWidth);
  return paddings
      .where((p) => p.padding != EdgeInsets.zero && p.padding != borderInset)
      .toList();
}

void main() {
  group('graphic-only banner (the reported bug)', () {
    for (final type in [
      SectionType.productCarousel,
      SectionType.categoryProductGrid,
    ]) {
      testWidgets(
          '${type.value}: banner is flush — 0 gap, full width, only top corners round',
          (tester) async {
        final entry = _entry(
          type: type,
          config: {
            'section_header': {'style': 'graphic', 'image_url': kBannerUrl},
            'container_background_color': '#FDF2E9',
            'container_top_radius': 20,
          },
        );
        await _mount(tester, entry);

        // No margin-like Padding wraps the banner in flush mode — it sits
        // directly under the container with zero inset on every side.
        // (Border-width insets are a separate concern, covered below.)
        expect(
          _nonZeroPaddingAncestors(tester, _bannerImage()),
          isEmpty,
          reason:
              'flush banner must not have any margin-like padding around it',
        );

        // Full section width: the banner's rendered width equals the
        // container's, not a horizontally-inset floating card.
        final container = _premiumContainer();
        expect(container, findsOneWidget);
        final containerWidth = tester.getSize(container).width;
        final bannerWidth = tester.getSize(_bannerImage()).width;
        expect(bannerWidth, closeTo(containerWidth, 0.5));

        // Banner starts at the very top of the container (y-position match).
        final containerTop = tester.getTopLeft(container).dy;
        final bannerTop = tester.getTopLeft(_bannerImage()).dy;
        expect(bannerTop, closeTo(containerTop, 0.5));

        // Only the container's TOP corners are rounded — never the bottom.
        final decoration =
            tester.widget<Container>(container).decoration! as BoxDecoration;
        final radius = decoration.borderRadius! as BorderRadius;
        expect(radius.topLeft, const Radius.circular(20));
        expect(radius.topRight, const Radius.circular(20));
        expect(radius.bottomLeft, Radius.zero);
        expect(radius.bottomRight, Radius.zero);
      });

      testWidgets('${type.value}: container background/border come from config',
          (tester) async {
        final entry = _entry(
          type: type,
          config: {
            'section_header': {'style': 'graphic', 'image_url': kBannerUrl},
            'container_background_color': '#FDF2E9',
            'container_border_color': '#D97706',
            'container_border_width': 3,
          },
        );
        await _mount(tester, entry);

        final container = _premiumContainer();
        expect(container, findsOneWidget);
        final decoration =
            tester.widget<Container>(container).decoration! as BoxDecoration;
        expect(decoration.color, const Color(0xFFFDF2E9));
        expect(decoration.border!.top.color, const Color(0xFFD97706));
        expect(decoration.border!.top.width, 3);

        // The banner is still "flush" — no margin-like Padding — it's only
        // inset by the border's own 3px stroke width so it doesn't render
        // underneath the border.
        expect(
          _nonZeroPaddingAncestors(
            tester,
            _bannerImage(),
            allowedBorderWidth: 3,
          ),
          isEmpty,
        );
        final bannerWidth = tester.getSize(_bannerImage()).width;
        expect(
          bannerWidth,
          closeTo(tester.getSize(container).width - 6, 0.5),
        );
      });

      testWidgets(
          '${type.value}: no border config at all → no border drawn (width 0)',
          (tester) async {
        final entry = _entry(
          type: type,
          config: {
            'section_header': {'style': 'graphic', 'image_url': kBannerUrl},
          },
        );
        await _mount(tester, entry);

        final container = _premiumContainer();
        expect(container, findsOneWidget);
        final decoration =
            tester.widget<Container>(container).decoration! as BoxDecoration;
        expect(decoration.border, isNull);
        // Still white by default, filling the whole body.
        expect(decoration.color, const Color(0xFFFFFFFF));
      });
    }
  });

  group('text_graphic style: text stays first, banner keeps its own gap', () {
    testWidgets(
        'the banner is NOT glued to the container edge when text renders above it',
        (tester) async {
      final entry = _entry(
        type: SectionType.productCarousel,
        config: {
          'section_header': {
            'style': 'text_graphic',
            'image_url': kBannerUrl,
          },
        },
      );
      await _mount(tester, entry);

      // In this mode the banner is still wrapped in a non-zero Padding (not
      // flush) — this fix only removes the gap when the banner IS the top
      // element.
      expect(_nonZeroPaddingAncestors(tester, _bannerImage()), hasLength(1));
    });
  });

  group('scope: only the Premium Fresh card style gets the container treatment',
      () {
    testWidgets('QUICK_COMMERCE_COMPACT renders no premium container wrapper',
        (tester) async {
      final entry = _entry(
        type: SectionType.categoryProductGrid,
        productCardStyle: 'QUICK_COMMERCE_COMPACT',
        config: {
          'section_header': {'style': 'graphic', 'image_url': kBannerUrl},
          'container_background_color': '#FDF2E9',
          // Just wide enough for a 2-column compact grid to lay out its
          // price/discount row without tripping the pre-existing (and
          // out-of-scope — this fix doesn't touch card internals) overflow
          // that a cramped 3-column default causes at phone width.
          'columns': 2,
        },
      );
      await _mount(tester, entry, width: 600);

      // No premium Container decoration at all for a non-premium card style —
      // ticket requires "Do not modify existing product-card design/business
      // logic" for the other styles.
      expect(_premiumContainer(), findsNothing);
    });
  });
}

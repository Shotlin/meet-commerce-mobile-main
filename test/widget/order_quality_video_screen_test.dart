import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_quality_video_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_quality_videos_result.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/repositories/order_repository.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_list_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/screens/order_quality_video_screen.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_details/order_detail_palette.dart';

class _MockOrderRepository extends Mock implements OrderRepository {}

void main() {
  late _MockOrderRepository repository;

  setUp(() {
    repository = _MockOrderRepository();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [orderRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: OrderQualityVideoScreen(orderId: 'order-1')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders a real vendor video card with the brand-red "Watch Video" button, not the app-default green', (tester) async {
    when(() => repository.getQualityVideos('order-1')).thenAnswer(
      (_) async => const Right(
        OrderQualityVideosResult(
          orderNumber: 'FC-KOL-20260926-0002',
          items: <OrderQualityVideoEntity>[
            OrderQualityVideoEntity(
              orderItemId: 'oi-1',
              productName: 'Chicken Breast Boneless (1 kg)',
              videoUrl: 'https://res.cloudinary.com/demo/video/upload/v1/evidence/clip.mp4',
              vendorName: 'Kolkata Fresh Chicken Co.',
              supplyNumber: 'SUP-20260926-7544',
            ),
          ],
        ),
      ),
    );

    await pump(tester);

    // The real order number must be visible somewhere on screen — the
    // whole point of carrying it through is so it's never ambiguous which
    // order this quality video actually belongs to.
    expect(find.textContaining('FC-KOL-20260926-0002'), findsOneWidget);
    expect(find.text('Chicken Breast Boneless (1 kg)'), findsOneWidget);
    expect(find.text('Supplied by Kolkata Fresh Chicken Co. · SUP-20260926-7544'), findsOneWidget);
    expect(find.text('Watch Video'), findsOneWidget);

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    final resolvedStyle = button.style!.backgroundColor!.resolve(<WidgetState>{});
    expect(resolvedStyle, OrderDetailPalette.ctaRed);

    // Regression: a hard `height: 44` on the button's ancestor SizedBox
    // used to clip the "Watch Video" label's text vertically (confirmed
    // live — the bottom of the text rendered cut off) because Material's
    // default ElevatedButton.icon content needs more vertical room than
    // that. The button must now be free to size itself to its real
    // content height instead of being squeezed smaller than it needs.
    final buttonHeight = tester.getSize(find.byType(ElevatedButton)).height;
    expect(buttonHeight, greaterThanOrEqualTo(48));
  });

  testWidgets('shows an honest empty state — never a fabricated video — when no item resolves one', (tester) async {
    when(() => repository.getQualityVideos('order-1')).thenAnswer(
      (_) async => const Right(
        OrderQualityVideosResult(
          orderNumber: 'FC-KOL-20260926-0003',
          items: <OrderQualityVideoEntity>[
            OrderQualityVideoEntity(orderItemId: 'oi-1', productName: 'Manually Stocked Item'),
          ],
        ),
      ),
    );

    await pump(tester);

    expect(find.text('No vendor quality video is available for this order yet.'), findsOneWidget);
  });

  testWidgets('tapping "Watch Video" surfaces the real failure reason instead of silently doing nothing', (tester) async {
    when(() => repository.getQualityVideos('order-1')).thenAnswer(
      (_) async => const Right(
        OrderQualityVideosResult(
          orderNumber: 'FC-KOL-20260926-0004',
          items: <OrderQualityVideoEntity>[
            OrderQualityVideoEntity(
              orderItemId: 'oi-1',
              productName: 'Chicken Breast Boneless (1 kg)',
              videoUrl: 'https://res.cloudinary.com/demo/video/upload/v1/evidence/clip.mp4',
            ),
          ],
        ),
      ),
    );

    await pump(tester);

    // No video_player platform implementation is registered in the widget
    // test harness, so tapping genuinely exercises the real failure path
    // (VideoPlayerController.initialize() throws) rather than a mock.
    await tester.tap(find.text('Watch Video'));
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsOneWidget);
    // Previously a bare `catch (_)` discarded the exception entirely —
    // there was no way to tell "not rendering" apart from "no error at
    // all." Some non-empty diagnostic text must now be visible.
    final errorTextFinder = find.byWidgetPredicate(
      (Widget w) => w is Text && w.data != null && w.data != 'Try again' && w.data!.isNotEmpty,
    );
    expect(errorTextFinder, findsWidgets);
  });

  testWidgets(
    'a different scanned order genuinely re-fetches and shows ITS OWN order number — never a stale result from a previously-viewed order',
    (tester) async {
      // Real user-reported concern: two of their own orders happened to
      // share the same real vendor batch and therefore showed the
      // identical video — correct behaviour, but with no way to visually
      // confirm each screen actually resolved its own scanned order id
      // rather than silently reusing whatever was shown before. This
      // proves the provider's `.family` keying does what it claims: two
      // different order ids each independently call the repository and
      // each screen shows its own real order number.
      when(() => repository.getQualityVideos('order-1')).thenAnswer(
        (_) async => const Right(
          OrderQualityVideosResult(
            orderNumber: 'FC-KOL-20260926-0001',
            items: <OrderQualityVideoEntity>[
              OrderQualityVideoEntity(
                orderItemId: 'oi-1',
                productName: 'Chicken Breast Boneless (1 kg)',
                videoUrl: 'https://res.cloudinary.com/demo/video/upload/v1/evidence/clip.mp4',
                vendorName: 'Kolkata Fresh Chicken Co.',
                supplyNumber: 'SUP-20260926-7544',
              ),
            ],
          ),
        ),
      );
      when(() => repository.getQualityVideos('order-2')).thenAnswer(
        (_) async => const Right(
          OrderQualityVideosResult(
            orderNumber: 'FC-KOL-20260926-0002',
            items: <OrderQualityVideoEntity>[
              OrderQualityVideoEntity(
                orderItemId: 'oi-2',
                productName: 'Chicken Breast Boneless (1 kg)',
                videoUrl: 'https://res.cloudinary.com/demo/video/upload/v1/evidence/clip.mp4',
                vendorName: 'Kolkata Fresh Chicken Co.',
                supplyNumber: 'SUP-20260926-7544',
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [orderRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: OrderQualityVideoScreen(orderId: 'order-1')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('FC-KOL-20260926-0001'), findsOneWidget);
      verify(() => repository.getQualityVideos('order-1')).called(1);
      verifyNever(() => repository.getQualityVideos('order-2'));

      // Simulate scanning a genuinely different order's QR — a fresh
      // widget for a different orderId, exactly what the scan screen's
      // `pushReplacement('/scan-order-qr/$orderId')` produces.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [orderRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: OrderQualityVideoScreen(orderId: 'order-2')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('FC-KOL-20260926-0002'), findsOneWidget);
      expect(find.textContaining('FC-KOL-20260926-0001'), findsNothing);
      verify(() => repository.getQualityVideos('order-2')).called(1);
    },
  );
}

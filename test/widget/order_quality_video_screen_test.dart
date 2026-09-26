import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_quality_video_entity.dart';
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
      (_) async => const Right(<OrderQualityVideoEntity>[
        OrderQualityVideoEntity(
          orderItemId: 'oi-1',
          productName: 'Chicken Breast Boneless (1 kg)',
          videoUrl: 'https://res.cloudinary.com/demo/video/upload/v1/evidence/clip.mp4',
          vendorName: 'Kolkata Fresh Chicken Co.',
          supplyNumber: 'SUP-20260926-7544',
        ),
      ]),
    );

    await pump(tester);

    expect(find.text('Chicken Breast Boneless (1 kg)'), findsOneWidget);
    expect(find.text('Supplied by Kolkata Fresh Chicken Co. · SUP-20260926-7544'), findsOneWidget);
    expect(find.text('Watch Video'), findsOneWidget);

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    final resolvedStyle = button.style!.backgroundColor!.resolve(<WidgetState>{});
    expect(resolvedStyle, OrderDetailPalette.ctaRed);
  });

  testWidgets('shows an honest empty state — never a fabricated video — when no item resolves one', (tester) async {
    when(() => repository.getQualityVideos('order-1')).thenAnswer(
      (_) async => const Right(<OrderQualityVideoEntity>[
        OrderQualityVideoEntity(orderItemId: 'oi-1', productName: 'Manually Stocked Item'),
      ]),
    );

    await pump(tester);

    expect(find.text('No vendor quality video is available for this order yet.'), findsOneWidget);
  });

  testWidgets('tapping "Watch Video" surfaces the real failure reason instead of silently doing nothing', (tester) async {
    when(() => repository.getQualityVideos('order-1')).thenAnswer(
      (_) async => const Right(<OrderQualityVideoEntity>[
        OrderQualityVideoEntity(
          orderItemId: 'oi-1',
          productName: 'Chicken Breast Boneless (1 kg)',
          videoUrl: 'https://res.cloudinary.com/demo/video/upload/v1/evidence/clip.mp4',
        ),
      ]),
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
}

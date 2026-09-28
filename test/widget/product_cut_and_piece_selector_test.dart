import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_cut_selector.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_piece_selector.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('ProductCutSelector', () {
    testWidgets('renders every admin-configured cut option', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProductCutSelector(
            options: const <String>['Tikka', 'Curry Cut', 'Boneless', 'Fillet'],
            selected: 'Tikka',
            onSelect: (_) {},
          ),
        ),
      );

      expect(find.text('Choose Your Cut'), findsOneWidget);
      expect(find.text('Tikka'), findsOneWidget);
      expect(find.text('Curry Cut'), findsOneWidget);
      expect(find.text('Boneless'), findsOneWidget);
      expect(find.text('Fillet'), findsOneWidget);
    });

    testWidgets('is not capped at any fixed number of options', (tester) async {
      final many = List<String>.generate(7, (i) => 'Cut $i');
      await tester.pumpWidget(
        _wrap(ProductCutSelector(options: many, selected: many.first, onSelect: (_) {})),
      );
      for (final label in many) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('tapping an option calls onSelect with that exact value', (tester) async {
      String? picked;
      await tester.pumpWidget(
        _wrap(
          ProductCutSelector(
            options: const <String>['Tikka', 'Fillet'],
            selected: 'Tikka',
            onSelect: (value) => picked = value,
          ),
        ),
      );

      await tester.tap(find.text('Fillet'));
      await tester.pump();
      expect(picked, 'Fillet');
    });
  });

  group('ProductPieceSelector', () {
    testWidgets('renders every admin-configured piece option, not limited to 3', (tester) async {
      final options = <String>['Small', 'Medium', 'Large', 'Extra Large'];
      await tester.pumpWidget(
        _wrap(ProductPieceSelector(options: options, selected: 'Small', onSelect: (_) {})),
      );

      expect(find.text('Available Pieces'), findsOneWidget);
      for (final label in options) {
        expect(find.text(label.toUpperCase()), findsOneWidget);
      }
    });

    testWidgets('tapping a chip calls onSelect with that exact value', (tester) async {
      String? picked;
      await tester.pumpWidget(
        _wrap(
          ProductPieceSelector(
            options: const <String>['Small', 'Medium', 'Large'],
            selected: 'Small',
            onSelect: (value) => picked = value,
          ),
        ),
      );

      await tester.tap(find.text('LARGE'));
      await tester.pump();
      expect(picked, 'Large');
    });
  });
}

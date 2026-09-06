import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_option_bottom_sheet.dart';

/// Lightweight notifier tracking whether the product option bottom sheet is
/// currently open. The floating cart pill watches this to hide itself while
/// the sheet is visible.
final productOptionSheetVisible = ValueNotifier<bool>(false);

/// Tracks whether the delivery address bottom sheet is open.
/// The floating cart pill watches this so it hides behind the sheet.
final addressSheetVisible = ValueNotifier<bool>(false);

/// Opens the variant option sheet for [product].
///
/// Matches the reference workflow: a dark dimmed overlay, a floating circular
/// close (X) button centred above the rounded-top sheet, then the option list.
///
/// Automatically hides the floating cart pill while the sheet is open.
void showProductOptionsSheet(BuildContext context, ProductEntity product) {
  // Hide floating cart pill while sheet is open.
  productOptionSheetVisible.value = true;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // Floating circular close button, centred above the sheet.
        Padding(
          padding: EdgeInsets.only(bottom: 14.h),
          child: Material(
            color: const Color(0xFF3A3A3A),
            shape: const CircleBorder(),
            elevation: 4,
            child: InkWell(
              onTap: () => Navigator.of(sheetContext).pop(),
              customBorder: const CircleBorder(),
              child: Padding(
                padding: EdgeInsets.all(9.w),
                child: PhosphorIcon(
                  PhosphorIcons.xBold,
                  size: 18.sp,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        ProductOptionBottomSheet(product: product),
      ],
    ),
  ).whenComplete(() {
    // Restore floating cart pill when sheet closes.
    productOptionSheetVisible.value = false;
  });
}

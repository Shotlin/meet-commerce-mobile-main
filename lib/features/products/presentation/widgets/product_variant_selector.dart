import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/products/data/models/product_options_response.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/providers/product_options_provider.dart';

const _kGreen = AppColors.brandRed;
const _kGreenBg = AppColors.brandRedSurface;
const _kBorderGrey = Color(0xFFE0E0E0);

/// "Select Unit" chip row shown on the product detail page for products
/// that belong to a multi-option family (e.g. Lite Dahi 80 g / 200 g).
/// Tapping a chip swaps the whole page to that variant in place via
/// [onSelect] — this widget itself holds no navigation logic.
class ProductVariantSelector extends ConsumerWidget {
  const ProductVariantSelector({
    required this.familyProductId,
    required this.selectedProductId,
    required this.onSelect,
    super.key,
  });

  /// Any member of the family — kept stable across variant switches so the
  /// options list is fetched (and cached) only once per screen instance.
  final String familyProductId;
  final String selectedProductId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optionsAsync = ref.watch(productOptionsProvider(familyProductId));

    return optionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (response) {
        final options = response.options;
        if (options.length < 2) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Select Weight',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              SizedBox(height: 10.h),
              // IntrinsicHeight (not a fixed SizedBox height) so the row is
              // exactly as tall as its content needs — a fixed height sized
              // for the tallest possible chip left short chips with a big
              // empty gap underneath. All chips still end up the same
              // height as each other (IntrinsicHeight's own contract), with
              // _VariantChip centering its content within that shared
              // height for shorter neighbours.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: IntrinsicHeight(
                  child: Row(
                    children: <Widget>[
                      for (int i = 0; i < options.length; i++) ...<Widget>[
                        if (i > 0) SizedBox(width: 10.w),
                        _VariantChip(
                          option: options[i],
                          isSelected: options[i].id == selectedProductId,
                          onTap: () => onSelect(options[i].id),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VariantChip extends StatelessWidget {
  const _VariantChip({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final ProductOptionItem option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDisabled = !option.inStock;
    final hasDiscount = option.discountPercent > 0;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: InkWell(
        borderRadius: BorderRadius.circular(10.r),
        onTap: isDisabled ? null : onTap,
        child: Container(
          constraints: BoxConstraints(minWidth: 94.w),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
          decoration: BoxDecoration(
            color: isSelected ? _kGreenBg : Colors.white,
            border: Border.all(
              color: isSelected ? _kGreen : _kBorderGrey,
              width: isSelected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                option.displayUnit,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: isSelected ? _kGreen : const Color(0xFF1A1A1A),
                ),
              ),
              SizedBox(height: 3.h),
              if (hasDiscount) ...<Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '₹${option.effectivePrice.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      'MRP ₹${option.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.sp,
                        height: 1.15,
                        color: const Color(0xFF999999),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${option.discountPercent}% OFF',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: _kGreen,
                  ),
                ),
              ] else
                Text(
                  'MRP ₹${option.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    color: const Color(0xFF444444),
                  ),
                ),
              if (isDisabled) ...<Widget>[
                SizedBox(height: 2.h),
                Text(
                  'Out of stock',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: const Color(0xFF999999),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

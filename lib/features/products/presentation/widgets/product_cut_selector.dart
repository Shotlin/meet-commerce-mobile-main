import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';

/// "Choose Your Cut" — a single-select row of admin-typed, customer-facing
/// cut styles (e.g. Tikka, Curry Cut, Boneless, Small Cubes, Fillet) shown
/// above the weight/size selector. Rendered as compact, content-sized boxes
/// in a single horizontal row (matching the app's existing "Select Weight"
/// box style) rather than a tall vertical list with a radio dot — the box
/// itself IS the selection state (filled/bordered red vs. plain), so no
/// separate indicator is needed. A box is never stretched to full width;
/// when the options don't all fit the screen, the row scrolls horizontally
/// instead of wrapping to a new line, so box size/spacing stays consistent
/// regardless of how many options an admin configures. Purely a same-SKU,
/// front-end choice — no price, stock or SKU impact, and nothing is sent to
/// the cart/order; hidden entirely by the caller (ProductEntity.hasCutOptions)
/// when the admin hasn't configured any options for this product.
class ProductCutSelector extends StatelessWidget {
  const ProductCutSelector({
    required this.options,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Choose Your Cut',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Select how you\'d like it cut',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5.sp,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 10.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: <Widget>[
                for (int i = 0; i < options.length; i++) ...<Widget>[
                  if (i > 0) SizedBox(width: 10.w),
                  _CutChip(
                    label: options[i],
                    isSelected: options[i] == selected,
                    onTap: () => onSelect(options[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CutChip extends StatelessWidget {
  const _CutChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brandRedSurface : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.brandRed : AppColors.borderLight,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10.r),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.brandRedDark : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';

/// "Available Pieces" — a single-select row of admin-typed, customer-facing
/// size/piece labels (e.g. Small, Medium, Large — or any other vocabulary
/// the admin types; not limited to exactly three). Purely a same-SKU,
/// front-end choice — no price, stock or SKU impact; hidden entirely by the
/// caller (ProductEntity.hasPieceOptions) when the admin hasn't configured
/// any options for this product.
class ProductPieceSelector extends StatelessWidget {
  const ProductPieceSelector({
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
            'Available Pieces :',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 12.h),
          if (options.length <= 4)
            // A small, fixed set (the common Small/Medium/Large case) reads
            // best as evenly-sized boxes spanning the full row, matching
            // the reference design — an arbitrary-length Wrap would leave
            // uneven gaps for just 2-4 items.
            Row(
              children: <Widget>[
                for (int i = 0; i < options.length; i++) ...<Widget>[
                  if (i > 0) SizedBox(width: 12.w),
                  Expanded(
                    child: _PieceChip(
                      label: options[i],
                      isSelected: options[i] == selected,
                      onTap: () => onSelect(options[i]),
                    ),
                  ),
                ],
              ],
            )
          else
            Wrap(
              spacing: 12.w,
              runSpacing: 12.h,
              children: <Widget>[
                for (final option in options)
                  _PieceChip(
                    label: option,
                    isSelected: option == selected,
                    onTap: () => onSelect(option),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PieceChip extends StatelessWidget {
  const _PieceChip({
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
        constraints: BoxConstraints(minWidth: 84.w),
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 11.h),
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
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: isSelected ? AppColors.brandRedDark : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

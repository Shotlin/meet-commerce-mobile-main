import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';

/// Inline "Quantity" stepper + "Add to Cart" button, matching the
/// reference's in-page layout. Wired to the same add/update handlers as
/// the screen's persistent bottom bar — either one keeps cart state in
/// sync since both ultimately call the same cart provider methods.
class ProductQuantityRow extends StatelessWidget {
  const ProductQuantityRow({
    required this.quantity,
    required this.price,
    required this.onIncrement,
    required this.onDecrement,
    required this.onAddToCart,
    this.disableIncrement = false,
    super.key,
  });

  final int quantity;
  final double price;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onAddToCart;
  final bool disableIncrement;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 18.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Quantity',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1414),
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            children: <Widget>[
              Container(
                height: 46.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100.r),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Row(
                  children: <Widget>[
                    _StepButton(
                      icon: PhosphorIcons.minusBold,
                      onTap: quantity > 0 ? onDecrement : null,
                    ),
                    SizedBox(
                      width: 34.w,
                      child: Center(
                        child: Text(
                          '$quantity',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1414),
                          ),
                        ),
                      ),
                    ),
                    _StepButton(
                      icon: PhosphorIcons.plusBold,
                      onTap: disableIncrement ? null : onIncrement,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Material(
                  color: AppColors.brandRed,
                  borderRadius: BorderRadius.circular(100.r),
                  child: InkWell(
                    onTap: onAddToCart,
                    borderRadius: BorderRadius.circular(100.r),
                    child: Container(
                      height: 46.h,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          PhosphorIcon(
                            PhosphorIcons.shoppingCartBold,
                            size: 17.sp,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Add to Cart',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14.5.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '  |  ₹${price.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14.5.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final PhosphorIconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44.w,
          height: 44.h,
          child: Center(
            child: PhosphorIcon(
              icon,
              size: 15.sp,
              color:
                  onTap == null ? const Color(0xFFCCCCCC) : AppColors.brandRed,
            ),
          ),
        ),
      ),
    );
  }
}

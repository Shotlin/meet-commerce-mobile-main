import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/shared/widgets/badge_count.dart';

class ProductBottomBar extends StatefulWidget {
  const ProductBottomBar({
    required this.product,
    required this.quantity,
    required this.onAddToCart,
    required this.onViewCart,
    required this.onQuantityChange,
    this.disableIncrement = false,
    super.key,
  });

  final ProductEntity product;
  final int quantity;
  final VoidCallback onAddToCart;
  final VoidCallback onViewCart;
  final ValueChanged<int> onQuantityChange;
  // Purchase-limits: greys out (and visually suppresses ripple on) the "+"
  // stepper when this product is at its limit. The tap handler stays wired
  // regardless — the actual block-and-toast happens at the call site that
  // owns `onQuantityChange`, this only controls the affordance.
  final bool disableIncrement;

  @override
  State<ProductBottomBar> createState() => _ProductBottomBarState();
}

class _ProductBottomBarState extends State<ProductBottomBar> {
  double _addScale = 1;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _handleAddTap() {
    widget.onAddToCart();
    _resetTimer?.cancel();
    setState(() {
      _addScale = 0.96;
    });
    _resetTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _addScale = 1;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0x14000000),
            blurRadius: 12.r,
            offset: Offset(0, -3.h),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: widget.quantity == 0
                ? AnimatedScale(
                    scale: _addScale,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _handleAddTap,
                        borderRadius: BorderRadius.circular(14.r),
                        splashColor: Colors.white.withValues(alpha: 0.15),
                        child: Container(
                          width: double.infinity,
                          height: 50.h,
                          decoration: BoxDecoration(
                            color: AppColors.pdViolet,
                            borderRadius: BorderRadius.circular(14.r),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: AppColors.pdVioletGlow,
                                blurRadius: 12.r,
                                offset: Offset(0, 4.h),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              PhosphorIcon(
                                PhosphorIcons.shoppingCartSimpleBold,
                                size: 20.sp,
                                color: Colors.white,
                              ),
                              SizedBox(width: 10.w),
                              Text(
                                'Add to cart',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.0,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : Row(
                    key: const ValueKey<String>('bottom-bar-quantity'),
                    children: <Widget>[
                      Expanded(
                        flex: 10,
                        child: _ViewCartButton(
                          quantity: widget.quantity,
                          onTap: widget.onViewCart,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        flex: 11,
                        child: _BottomQuantityControl(
                          quantity: widget.quantity,
                          onIncrement: () =>
                              widget.onQuantityChange(widget.quantity + 1),
                          onDecrement: () => widget.onQuantityChange(
                            widget.quantity > 0 ? widget.quantity - 1 : 0,
                          ),
                          disableIncrement: widget.disableIncrement,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ViewCartButton extends StatelessWidget {
  const _ViewCartButton({
    required this.quantity,
    required this.onTap,
  });

  final int quantity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          height: 50.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: const Color(0xFFE5E5E5)),
          ),
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.only(top: 1.h),
                    child: PhosphorIcon(
                      PhosphorIcons.shoppingCartSimpleBold,
                      size: 20.sp,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  Positioned(
                    right: -8.w,
                    top: -7.h,
                    child: BadgeCount(count: quantity),
                  ),
                ],
              ),
              SizedBox(width: 10.w),
              Text(
                'View Cart',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomQuantityControl extends StatelessWidget {
  const _BottomQuantityControl({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.disableIncrement = false,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final bool disableIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50.h,
      decoration: BoxDecoration(
        color: AppColors.pdViolet,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: <Widget>[
          _QtyActionButton(
            icon: PhosphorIcons.minusBold,
            onTap: onDecrement,
          ),
          Expanded(
            child: Center(
              child: Text(
                '$quantity',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          _QtyActionButton(
            icon: PhosphorIcons.plusBold,
            onTap: onIncrement,
            disabled: disableIncrement,
          ),
        ],
      ),
    );
  }
}

class _QtyActionButton extends StatelessWidget {
  const _QtyActionButton({
    required this.icon,
    required this.onTap,
    this.disabled = false,
  });

  final PhosphorIconData icon;
  final VoidCallback onTap;
  // Purely visual — the tap handler always stays wired so a stale cache
  // can still be caught (and toasted) at the call site instead of the tap
  // silently doing nothing.
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        splashColor: disabled ? Colors.transparent : null,
        highlightColor: disabled ? Colors.transparent : null,
        child: SizedBox(
          width: 48.w,
          height: double.infinity,
          child: Center(
            child: Opacity(
              opacity: disabled ? 0.4 : 1,
              child: PhosphorIcon(
                icon,
                size: 18.sp,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

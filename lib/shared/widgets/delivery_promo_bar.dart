import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';

class DeliveryPromoBar extends ConsumerWidget {
  const DeliveryPromoBar({super.key});

  static const double _freeDeliveryThreshold = 99.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartTotal = ref.watch(cartTotalProvider);
    final remaining = (_freeDeliveryThreshold - cartTotal).clamp(0.0, _freeDeliveryThreshold);
    final show = remaining > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      height: show ? 56.h : 0,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          children: <Widget>[
            PhosphorIcon(
              PhosphorIcons.lockSimple,
              size: 18.sp,
              color: const Color(0xFFFFD700),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Unlock free delivery',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Shop for ₹${remaining.toStringAsFixed(0)} more',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFFBBBBBB),
                    ),
                  ),
                ],
              ),
            ),
            // Optional: "Add Items" arrow
            PhosphorIcon(
              PhosphorIcons.caretRight,
              size: 16.sp,
              color: const Color(0xFF888888),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_timeline_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_details/order_detail_palette.dart';

const _dangerRed = Color(0xFFD32F2F);

/// Item 9 — the safe-area-aware sticky footer: "Need Help?" always on the
/// left, and a primary action on the right that tracks the order's real
/// status rather than a fixed "Buy Again" for every state (an order still
/// being packed needs Cancel, not Buy Again; a dispatched one needs Track).
class StickyOrderActions extends StatelessWidget {
  const StickyOrderActions({
    required this.order,
    required this.onNeedHelp,
    required this.onPrimaryAction,
    required this.isBusy,
    super.key,
  });

  final OrderEntity order;
  final VoidCallback onNeedHelp;
  final VoidCallback onPrimaryAction;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final (String label, IconData icon, Color color) = switch (order.status) {
      OrderStatus.PENDING ||
      OrderStatus.CONFIRMED ||
      OrderStatus.PREPARING =>
        ('Cancel Order', PhosphorIcons.xCircle, _dangerRed),
      OrderStatus.PACKED ||
      OrderStatus.OUT_FOR_DELIVERY =>
        ('Track Order', PhosphorIcons.navigationArrow, OrderDetailPalette.ctaRed),
      OrderStatus.DELIVERED ||
      OrderStatus.CANCELLED ||
      OrderStatus.REFUNDED =>
        ('Buy Again', PhosphorIcons.shoppingCartSimple, OrderDetailPalette.ctaRed),
    };

    return Container(
      decoration: const BoxDecoration(
        color: OrderDetailPalette.white,
        border: Border(top: BorderSide(color: OrderDetailPalette.border)),
        boxShadow: <BoxShadow>[OrderDetailPalette.stickyBarShadow],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
          child: Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: 48.h,
                  child: OutlinedButton.icon(
                    onPressed: onNeedHelp,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OrderDetailPalette.textPrimary,
                      side: const BorderSide(color: OrderDetailPalette.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    icon: Icon(PhosphorIcons.headset, size: 17.sp),
                    label: Text(
                      'Need Help?',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              Gap(10.w),
              Expanded(
                child: SizedBox(
                  height: 48.h,
                  child: FilledButton.icon(
                    onPressed: isBusy ? null : onPrimaryAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      disabledBackgroundColor: color.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    icon: isBusy
                        ? SizedBox(
                            width: 16.w,
                            height: 16.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(icon, size: 17.sp),
                    label: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:bakaloo_flutter_app/features/cart/domain/entities/savings_breakdown_entity.dart';

class CartSavingsBreakdown extends StatelessWidget {
  const CartSavingsBreakdown({required this.savings, super.key});

  final SavingsBreakdownEntity savings;

  static const _iconConfig = <String, _SavingsIconData>{
    'mrp_discount': _SavingsIconData(Color(0xFFF5A623), '%'),
    'handling_waiver': _SavingsIconData(Color(0xFFFF6B35), '₹'),
    'late_night_waiver': _SavingsIconData(Color(0xFF0AC26B), '✓'),
    'first_time_offer': _SavingsIconData(Color(0xFF0AC26B), '🎁'),
  };

  @override
  Widget build(BuildContext context) {
    if (savings.total <= 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Savings on this order',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF222222),
                    fontFamily: 'Inter',
                  ),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0AC26B),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    '₹${savings.total.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
            Gap(16.h),
            ...List<Widget>.generate(
              savings.items.length,
              (index) {
                final item = savings.items[index];
                final config = _iconConfig[item.type] ??
                    const _SavingsIconData(Color(0xFF0AC26B), '✓');

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == savings.items.length - 1 ? 0 : 14.h,
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 32.w,
                        height: 32.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: config.color,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          config.symbol,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                      Gap(12.w),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF666666),
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                      Gap(10.w),
                      Text(
                        '₹${item.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF222222),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SavingsIconData {
  const _SavingsIconData(this.color, this.symbol);
  final Color color;
  final String symbol;
}

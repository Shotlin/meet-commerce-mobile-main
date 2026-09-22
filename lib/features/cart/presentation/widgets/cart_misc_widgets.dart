import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CartGstInvoice extends StatelessWidget {
  const CartGstInvoice({
    super.key,
    this.onTap,
  });

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.receipt_long_outlined,
                size: 20.sp,
                color: const Color(0xFF5E5E5E),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Get GST Invoice',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF222222),
                        fontFamily: 'Inter',
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      'Claim up to 28% input tax credit on eligible business orders.',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF777777),
                        height: 1.4,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Icon(
                Icons.chevron_right_rounded,
                size: 20.sp,
                color: const Color(0xFF8D8D8D),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Titled "Policies" section — three bullet points covering the same real
/// rules the previous single-paragraph `CartCancellationPolicy` stated
/// (item/quantity changes, cancellation-after-packing, and rescheduling),
/// just laid out to match a scannable bullet list instead of one paragraph.
class CartPoliciesSection extends StatelessWidget {
  const CartPoliciesSection({super.key});

  static const List<String> _bullets = <String>[
    'Item or quantity changes aren\'t possible after you place your '
        'order — please review your cart carefully before checkout.',
    'Orders can be cancelled any time before they\'re packed for '
        'delivery. Once packed, cancellation may not be possible; any '
        'eligible refund is processed automatically.',
    'You can reschedule your delivery slot any time before it\'s '
        'dispatched — use "Change Slot" above.',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 18.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Policies',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A1A),
              fontFamily: 'Inter',
            ),
          ),
          SizedBox(height: 10.h),
          ...List<Widget>.generate(_bullets.length, (index) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == _bullets.length - 1 ? 0 : 8.h,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.only(top: 6.h),
                    child: Container(
                      width: 4.w,
                      height: 4.w,
                      decoration: const BoxDecoration(
                        color: Color(0xFF999999),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      _bullets[index],
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF777777),
                        height: 1.45,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class CartSectionDivider extends StatelessWidget {
  const CartSectionDivider({
    super.key,
    this.height,
  });

  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height ?? 8.h,
      color: const Color(0xFFF5F5F5),
    );
  }
}

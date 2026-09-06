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

class CartCancellationPolicy extends StatelessWidget {
  const CartCancellationPolicy({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.info_outline_rounded,
            size: 18.sp,
            color: const Color(0xFF8A8A8A),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'Orders cannot be cancelled after they are packed for delivery. If there is an unexpected delay, any applicable refund will be processed.',
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

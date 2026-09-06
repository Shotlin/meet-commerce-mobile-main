import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CartWishlistCta extends StatelessWidget {
  const CartWishlistCta({
    super.key,
    this.onTap,
  });

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.favorite_rounded,
            size: 20.sp,
            color: const Color(0xFFE23372),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'Add items from your wishlist',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF222222),
                fontFamily: 'Inter',
              ),
            ),
          ),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0AC26B),
              side: const BorderSide(color: Color(0xFF0AC26B)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              minimumSize: Size(0, 38.h),
            ),
            child: Text(
              '+ Add',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0AC26B),
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

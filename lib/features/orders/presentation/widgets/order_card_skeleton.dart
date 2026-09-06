import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/shared/widgets/skeleton_loader.dart';

/// Shimmer placeholder that mirrors the [OrderCard] layout while loading.
class OrderCardSkeleton extends StatelessWidget {
  const OrderCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.orderCardBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.orderCardShadow,
            blurRadius: 3.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      padding: EdgeInsets.all(14.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SkeletonLoader(width: 88.w, height: 88.w, radius: 16.r),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SkeletonLoader(width: 140.w, height: 13.h),
                    SizedBox(height: 8.h),
                    SkeletonLoader(width: 110.w, height: 11.h),
                    SizedBox(height: 12.h),
                    SkeletonLoader(width: double.infinity, height: 13.h),
                    SizedBox(height: 6.h),
                    SkeletonLoader(width: 80.w, height: 11.h),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: <Widget>[
              Expanded(child: SkeletonLoader(height: 44.h, radius: 12.r)),
              SizedBox(width: 10.w),
              Expanded(child: SkeletonLoader(height: 44.h, radius: 12.r)),
            ],
          ),
        ],
      ),
    );
  }
}

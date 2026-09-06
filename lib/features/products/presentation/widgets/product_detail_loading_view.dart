import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/shared/widgets/skeleton_loader.dart';

class ProductDetailLoadingView extends StatelessWidget {
  const ProductDetailLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              pinned: true,
              expandedHeight: 420.h,
              backgroundColor: AppColors.bgSection,
              flexibleSpace: const FlexibleSpaceBar(
                background: SkeletonLoader(height: 420, radius: 0),
              ),
            ),
            SliverToBoxAdapter(
              child: RepaintBoundary(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SkeletonLoader(height: 36, radius: 0),
                    Padding(
                      padding: EdgeInsets.all(16.w),
                      child: const SkeletonLoader(height: 108, radius: 16),
                    ),
                    Container(
                      width: double.infinity,
                      color: AppColors.bgSection,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 16.h,
                      ),
                      child: const Column(
                        children: <Widget>[
                          SkeletonLoader(height: 80, radius: 12),
                          SizedBox(height: 10),
                          SkeletonLoader(height: 80, radius: 12),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(16.w),
                      child: const SkeletonLoader(height: 180, radius: 16),
                    ),
                    SizedBox(height: 92.h),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          left: 16.w,
          right: 16.w,
          bottom: 10.h,
          child: const SafeArea(
            top: false,
            child: SkeletonLoader(height: 50, radius: 14),
          ),
        ),
      ],
    );
  }
}

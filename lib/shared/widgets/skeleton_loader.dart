import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';

/// A single shimmer placeholder box.
///
/// For best performance, wrap multiple [SkeletonLoader]s in a single
/// [SkeletonShimmerGroup] so they share one animation controller instead of
/// each running an independent shimmer cycle.
class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    this.width,
    this.height = 16,
    this.radius = 12,
    this.shape = BoxShape.rectangle,
    this.useOwnShimmer = true,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  /// When false, this loader renders only the colored box (no Shimmer wrapper).
  /// Used when a parent [SkeletonShimmerGroup] provides the shimmer animation.
  final bool useOwnShimmer;

  const SkeletonLoader.circular({
    required double size,
    this.useOwnShimmer = true,
    super.key,
  })  : width = size,
        height = size,
        radius = size / 2,
        shape = BoxShape.circle;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.bgSkeleton,
        shape: shape,
        borderRadius:
            shape == BoxShape.circle ? null : BorderRadius.circular(radius),
      ),
    );

    if (!useOwnShimmer) return box;

    return Shimmer.fromColors(
      baseColor: AppColors.bgSkeleton,
      highlightColor: AppColors.shimmerHighlight,
      child: box,
    );
  }
}

/// Wraps multiple skeleton children in a single [Shimmer] animation controller.
///
/// This is significantly cheaper than N independent [SkeletonLoader] widgets
/// each running their own [AnimationController]. Use this around groups of
/// skeleton placeholders that are visible together (e.g. the home loading
/// view or section-level skeletons).
class SkeletonShimmerGroup extends StatelessWidget {
  const SkeletonShimmerGroup({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.bgSkeleton,
      highlightColor: AppColors.shimmerHighlight,
      child: child,
    );
  }
}

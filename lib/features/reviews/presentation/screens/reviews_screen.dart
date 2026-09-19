import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/datetime_extensions.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/entities/review_entity.dart';
import 'package:bakaloo_flutter_app/features/reviews/presentation/providers/review_provider.dart';
import 'package:bakaloo_flutter_app/features/reviews/presentation/screens/write_review_screen.dart';
import 'package:bakaloo_flutter_app/shared/widgets/confirmation_dialog.dart';

Future<void> showProductReviewsBottomSheet(
  BuildContext context, {
  required String productId,
  required String productName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ProductReviewsBottomSheet(
      productId: productId,
      productName: productName,
    ),
  );
}

class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  static const int _pageSize = 10;
  late final PagingController<int, ReviewEntity> _pagingController;

  @override
  void initState() {
    super.initState();
    _pagingController = PagingController<int, ReviewEntity>(firstPageKey: 1)
      ..addPageRequestListener(_fetchPage);
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int pageKey) async {
    final result = await ref.read(reviewProvider.notifier).getMyReviews(
          page: pageKey,
          limit: _pageSize,
        );

    result.fold(
      (failure) {
        _pagingController.error = failure.message;
      },
      (data) {
        final isLastPage = data.pagination.totalPages <= pageKey ||
            data.reviews.length < _pageSize;
        if (isLastPage) {
          _pagingController.appendLastPage(data.reviews);
          return;
        }
        _pagingController.appendPage(data.reviews, pageKey + 1);
      },
    );
  }

  Future<void> _editReview(ReviewEntity review) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => WriteReviewScreen(
          reviewId: review.id,
          productId: review.productId,
          productName: review.productName ?? 'Product',
          productImage: review.productImage,
          initialRating: review.rating,
          initialComment: review.comment ?? '',
        ),
      ),
    );

    if (!mounted || changed != true) {
      return;
    }
    _pagingController.refresh();
  }

  Future<void> _deleteReview(ReviewEntity review) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete review?',
      message: 'This review will be removed permanently.',
      confirmLabel: 'Delete',
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final result = await ref.read(reviewProvider.notifier).deleteReview(
          review.id,
        );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess ? 'Review deleted.' : result.failure!.message,
        ),
        backgroundColor:
            result.isSuccess ? AppColors.successGreen : AppColors.outOfStockRed,
      ),
    );

    if (result.isSuccess) {
      _pagingController.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text('My Reviews', style: AppTextStyles.h2),
      ),
      body: PagedListView<int, ReviewEntity>(
        pagingController: _pagingController,
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
        builderDelegate: PagedChildBuilderDelegate<ReviewEntity>(
          itemBuilder: (context, review, index) {
            return Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: _MyReviewCard(
                review: review,
                onEdit: () => _editReview(review),
                onDelete: () => _deleteReview(review),
              ),
            );
          },
          firstPageProgressIndicatorBuilder: (_) => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          ),
          firstPageErrorIndicatorBuilder: (_) => _ReviewsErrorState(
            message: _pagingController.error?.toString() ??
                'Unable to load reviews.',
            onRetry: _pagingController.refresh,
          ),
          noItemsFoundIndicatorBuilder: (_) => const _NoReviewsState(),
        ),
      ),
    );
  }
}

class _MyReviewCard extends StatelessWidget {
  const _MyReviewCard({
    required this.review,
    required this.onEdit,
    required this.onDelete,
  });

  final ReviewEntity review;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 58.w,
                height: 58.w,
                decoration: BoxDecoration(
                  color: AppColors.bgSection,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                clipBehavior: Clip.antiAlias,
                child: (review.productImage ?? '').isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: review.productImage!,
                        memCacheWidth: 300,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Center(
                          child: PhosphorIcon(
                            PhosphorIcons.image,
                            color: AppColors.textDisabled,
                          ),
                        ),
                      )
                    : Center(
                        child: PhosphorIcon(
                          PhosphorIcons.image,
                          color: AppColors.textDisabled,
                        ),
                      ),
              ),
              Gap(12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      review.productName ?? 'Product',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Gap(4.h),
                    _StarsRow(rating: review.rating, starSize: 16),
                    Gap(4.h),
                    Text(
                      review.createdAt.toIndianDate,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((review.comment ?? '').isNotEmpty) ...<Widget>[
            Gap(10.h),
            Text(
              review.comment!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
          Gap(10.h),
          Row(
            children: <Widget>[
              TextButton(
                onPressed: onEdit,
                child: Text(
                  'Edit',
                  style: AppTextStyles.buttonMedium.copyWith(
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              TextButton(
                onPressed: onDelete,
                child: Text(
                  'Delete',
                  style: AppTextStyles.buttonMedium.copyWith(
                    color: AppColors.outOfStockRed,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductReviewsBottomSheet extends ConsumerStatefulWidget {
  const _ProductReviewsBottomSheet({
    required this.productId,
    required this.productName,
  });

  final String productId;
  final String productName;

  @override
  ConsumerState<_ProductReviewsBottomSheet> createState() =>
      _ProductReviewsBottomSheetState();
}

class _ProductReviewsBottomSheetState
    extends ConsumerState<_ProductReviewsBottomSheet> {
  static const int _pageSize = 10;
  late final PagingController<int, ReviewEntity> _pagingController;

  double _averageRating = 0;
  Map<int, double> _distribution = <int, double>{
    5: 0,
    4: 0,
    3: 0,
    2: 0,
    1: 0,
  };

  @override
  void initState() {
    super.initState();
    _pagingController = PagingController<int, ReviewEntity>(firstPageKey: 1)
      ..addPageRequestListener(_fetchPage);
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int pageKey) async {
    final result = await ref.read(reviewProvider.notifier).getProductReviews(
          productId: widget.productId,
          page: pageKey,
          limit: _pageSize,
        );

    result.fold(
      (failure) {
        _pagingController.error = failure.message;
      },
      (data) {
        final existing = pageKey == 1
            ? <ReviewEntity>[]
            : <ReviewEntity>[...?_pagingController.itemList];
        final merged = <ReviewEntity>[
          ...existing,
          ...data.reviews,
        ];

        setState(() {
          _averageRating = data.averageRating;
          _distribution = _calculateDistribution(merged);
        });

        final isLastPage = data.pagination.totalPages <= pageKey ||
            data.reviews.length < _pageSize;
        if (isLastPage) {
          _pagingController.appendLastPage(data.reviews);
          return;
        }
        _pagingController.appendPage(data.reviews, pageKey + 1);
      },
    );
  }

  Map<int, double> _calculateDistribution(List<ReviewEntity> reviews) {
    if (reviews.isEmpty) {
      return <int, double>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    }

    final distribution = <int, double>{};
    final total = reviews.length;
    for (var star = 5; star >= 1; star--) {
      final count = reviews.where((review) => review.rating == star).length;
      distribution[star] = count / total;
    }
    return distribution;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 0.88.sh,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 20.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(widget.productName, style: AppTextStyles.h2),
            Gap(12.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _averageRating.toStringAsFixed(1),
                  style: AppTextStyles.display.copyWith(
                    fontSize: 36.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Gap(10.w),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      for (var star = 5; star >= 1; star--)
                        Padding(
                          padding: EdgeInsets.only(bottom: 6.h),
                          child: _DistributionRow(
                            star: star,
                            progress: _distribution[star] ?? 0,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Gap(10.h),
            Expanded(
              child: PagedListView<int, ReviewEntity>(
                pagingController: _pagingController,
                builderDelegate: PagedChildBuilderDelegate<ReviewEntity>(
                  itemBuilder: (context, review, index) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 10.h),
                      child: _ReviewTile(review: review),
                    );
                  },
                  firstPageProgressIndicatorBuilder: (_) => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  firstPageErrorIndicatorBuilder: (_) => _ReviewsErrorState(
                    message: _pagingController.error?.toString() ??
                        'Unable to load product reviews.',
                    onRetry: _pagingController.refresh,
                  ),
                  noItemsFoundIndicatorBuilder: (_) => Center(
                    child: Text(
                      'No reviews yet.',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.star,
    required this.progress,
  });

  final int star;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 26.w,
          child: Text(
            '$star★',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Gap(8.w),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8.h,
              backgroundColor: AppColors.borderLight,
              color: AppColors.ratingGold,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.review,
  });

  final ReviewEntity review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  review.userName ?? 'Bakaloo Customer',
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                review.createdAt.toRelative,
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
          Gap(6.h),
          _StarsRow(rating: review.rating, starSize: 16),
          if ((review.comment ?? '').isNotEmpty) ...<Widget>[
            Gap(6.h),
            Text(
              review.comment!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StarsRow extends StatelessWidget {
  const _StarsRow({
    required this.rating,
    required this.starSize,
  });

  final int rating;
  final double starSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(5, (index) {
        final isFilled = index < rating;
        return Padding(
          padding: EdgeInsets.only(right: 2.w),
          child: PhosphorIcon(
            isFilled ? PhosphorIcons.starFill : PhosphorIcons.star,
            size: starSize.sp,
            color: isFilled ? AppColors.ratingGold : AppColors.borderLight,
          ),
        );
      }),
    );
  }
}

class _NoReviewsState extends StatelessWidget {
  const _NoReviewsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Text(
          'You have not posted any reviews yet.',
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ReviewsErrorState extends StatelessWidget {
  const _ReviewsErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            Gap(10.h),
            FilledButton(
              onPressed: onRetry,
              child: Text('Retry', style: AppTextStyles.buttonMedium),
            ),
          ],
        ),
      ),
    );
  }
}

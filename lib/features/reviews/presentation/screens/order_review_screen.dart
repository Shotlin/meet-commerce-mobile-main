import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/datetime_extensions.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/repositories/review_repository.dart';
import 'package:bakaloo_flutter_app/features/reviews/presentation/providers/review_provider.dart';

/// Shown after a customer opens a DELIVERED order — one screen for every
/// product in that order, each with its own star rating and optional
/// comment, submitted together. Rating a product is optional per product
/// (an unrated product is silently skipped on submit); the DB's
/// (user_id, order_id, product_id) unique constraint means re-opening this
/// screen for the same order and submitting again is a safe no-op for
/// whatever was already reviewed — the per-item submit below treats that
/// as "already done", not an error to surface.
class OrderReviewScreen extends ConsumerStatefulWidget {
  const OrderReviewScreen({required this.order, super.key});

  final OrderEntity order;

  @override
  ConsumerState<OrderReviewScreen> createState() => _OrderReviewScreenState();
}

class _OrderReviewScreenState extends ConsumerState<OrderReviewScreen> {
  late final Map<String, int> _ratings;
  late final Map<String, TextEditingController> _commentControllers;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _ratings = <String, int>{
      for (final OrderItemEntity item in widget.order.items) item.productId: 0,
    };
    _commentControllers = <String, TextEditingController>{
      for (final OrderItemEntity item in widget.order.items)
        item.productId: TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int _ratedCount(Set<String> alreadyReviewed) => _ratings.entries
      .where((e) => e.value > 0 && !alreadyReviewed.contains(e.key))
      .length;

  Future<void> _submit(Set<String> alreadyReviewed) async {
    if (_ratedCount(alreadyReviewed) == 0) {
      AppToast.show(context, '⚠️ Rate at least one product to submit.', type: ToastType.warning);
      return;
    }

    setState(() {
      _submitting = true;
    });

    var succeeded = 0;
    var alreadyReviewedCount = 0;
    String? hardFailureMessage;

    for (final item in widget.order.items) {
      // Already reviewed for this exact order — the card renders read-only
      // for these, so there's nothing new to submit.
      if (alreadyReviewed.contains(item.productId)) {
        continue;
      }
      final rating = _ratings[item.productId] ?? 0;
      if (rating <= 0) {
        continue;
      }
      final comment = _commentControllers[item.productId]!.text.trim();
      final result = await ref.read(reviewProvider.notifier).createReview(
            ReviewCreateParams(
              productId: item.productId,
              orderId: widget.order.id,
              rating: rating,
              comment: comment.isEmpty ? null : comment,
            ),
          );

      if (result.isSuccess) {
        succeeded++;
        continue;
      }

      // The backend rejects a duplicate (user_id, order_id, product_id) —
      // that's an expected "already reviewed this one" outcome, not a
      // real failure, so it doesn't block the rest of the batch or read
      // as an error to the customer.
      final message = result.failure!.message;
      if (message.toLowerCase().contains('already reviewed')) {
        alreadyReviewedCount++;
      } else {
        hardFailureMessage ??= message;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
    });

    if (succeeded == 0) {
      AppToast.show(
        context,
        hardFailureMessage ??
            (alreadyReviewedCount > 0
                ? 'You already reviewed these products for this order.'
                : 'Unable to submit your review right now.'),
      );
      return;
    }

    // A fresh submit changes which products are "already reviewed" for
    // this order — refresh so the read-only state is correct if the
    // customer navigates back into this screen again.
    ref.invalidate(orderReviewsProvider(widget.order.id));

    await _showConfirmation(succeeded);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _showConfirmation(int reviewedCount) async {
    final authState = ref.read(authStateProvider);
    final reviewerName = switch (authState) {
      AuthAuthenticated(:final user) =>
        (user.name ?? '').trim().isNotEmpty ? user.name!.trim() : 'You',
      _ => 'You',
    };
    final submittedAt = DateTime.now();

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => _ReviewSubmittedSheet(
        reviewerName: reviewerName,
        submittedAt: submittedAt,
        reviewedCount: reviewedCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existingReviewsAsync =
        ref.watch(orderReviewsProvider(widget.order.id));
    final existingReviews = existingReviewsAsync.asData?.value ??
        const <String, ({int rating, String? comment})>{};
    final alreadyReviewed = existingReviews.keys.toSet();
    final ratedCount = _ratedCount(alreadyReviewed);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text('Rate Your Order', style: AppTextStyles.h2),
        actions: <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: TextButton(
              onPressed: (_submitting || ratedCount == 0)
                  ? null
                  : () => _submit(alreadyReviewed),
              child: _submitting
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      ratedCount > 0 ? 'Submit ($ratedCount)' : 'Submit',
                      style: AppTextStyles.buttonMedium.copyWith(
                        color: ratedCount > 0
                            ? AppColors.primaryGreen
                            : AppColors.textDisabled,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
        itemCount: widget.order.items.length,
        separatorBuilder: (_, __) => Gap(14.h),
        itemBuilder: (context, index) {
          final item = widget.order.items[index];
          final existing = existingReviews[item.productId];
          if (existing != null) {
            return _AlreadyReviewedCard(
              item: item,
              rating: existing.rating,
              comment: existing.comment,
            );
          }
          return _ProductReviewCard(
            item: item,
            rating: _ratings[item.productId] ?? 0,
            commentController: _commentControllers[item.productId]!,
            onRatingChanged: (star) {
              setState(() {
                _ratings[item.productId] = star;
              });
            },
          );
        },
      ),
    );
  }
}

class _ProductReviewCard extends StatelessWidget {
  const _ProductReviewCard({
    required this.item,
    required this.rating,
    required this.commentController,
    required this.onRatingChanged,
  });

  final OrderItemEntity item;
  final int rating;
  final TextEditingController commentController;
  final ValueChanged<int> onRatingChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
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
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: AppColors.bgSection,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                clipBehavior: Clip.antiAlias,
                child: (item.thumbnailUrl ?? '').isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.thumbnailUrl!,
                        memCacheWidth: 260,
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
                child: Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Gap(10.h),
          Row(
            children: List<Widget>.generate(5, (index) {
              final star = index + 1;
              final isSelected = star <= rating;
              return GestureDetector(
                onTap: () => onRatingChanged(star),
                child: SizedBox(
                  width: 38.w,
                  height: 38.w,
                  child: Center(
                    child: AnimatedScale(
                      scale: isSelected ? 1.12 : 1,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutBack,
                      child: PhosphorIcon(
                        isSelected ? PhosphorIcons.starFill : PhosphorIcons.star,
                        size: 26.sp,
                        color: isSelected
                            ? AppColors.ratingGold
                            : AppColors.borderLight,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          Gap(8.h),
          TextField(
            controller: commentController,
            maxLength: 500,
            maxLines: 3,
            style: AppTextStyles.bodyMedium,
            decoration: const InputDecoration(
              hintText: 'Add a comment (optional)',
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only twin of _ProductReviewCard for a product that already has a
/// review for THIS order — filled stars matching what was actually
/// submitted, no tap targets, no editable comment box. Placing the same
/// order again for this product starts a fresh (editable) card on that
/// new order's own review screen, since the constraint is per order.
class _AlreadyReviewedCard extends StatelessWidget {
  const _AlreadyReviewedCard({
    required this.item,
    required this.rating,
    required this.comment,
  });

  final OrderItemEntity item;
  final int rating;
  final String? comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.bgSection,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                clipBehavior: Clip.antiAlias,
                child: (item.thumbnailUrl ?? '').isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.thumbnailUrl!,
                        memCacheWidth: 260,
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
                child: Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    PhosphorIcon(
                      PhosphorIcons.checkCircleFill,
                      size: 13.sp,
                      color: AppColors.primaryGreen,
                    ),
                    Gap(4.w),
                    Text(
                      'Reviewed',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gap(10.h),
          Row(
            children: List<Widget>.generate(5, (index) {
              final isSelected = index < rating;
              return SizedBox(
                width: 38.w,
                height: 38.w,
                child: Center(
                  child: PhosphorIcon(
                    isSelected ? PhosphorIcons.starFill : PhosphorIcons.star,
                    size: 26.sp,
                    color: isSelected
                        ? AppColors.ratingGold
                        : AppColors.borderLight,
                  ),
                ),
              );
            }),
          ),
          if ((comment ?? '').trim().isNotEmpty) ...<Widget>[
            Gap(4.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Text(
                comment!.trim(),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewSubmittedSheet extends StatelessWidget {
  const _ReviewSubmittedSheet({
    required this.reviewerName,
    required this.submittedAt,
    required this.reviewedCount,
  });

  final String reviewerName;
  final DateTime submittedAt;
  final int reviewedCount;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: EdgeInsets.all(16.w),
        padding: EdgeInsets.fromLTRB(20.w, 28.h, 20.w, 20.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          boxShadow: const <BoxShadow>[AppShadows.floatingShadow],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.elasticOut,
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: child,
              ),
              child: Container(
                width: 72.w,
                height: 72.w,
                decoration: const BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 40.sp,
                ),
              ),
            ),
            Gap(16.h),
            Text(
              reviewedCount > 1
                  ? 'Reviews submitted!'
                  : 'Review submitted!',
              style: AppTextStyles.h2,
            ),
            Gap(6.h),
            Text(
              reviewedCount > 1
                  ? 'Thanks for rating $reviewedCount products.'
                  : 'Thanks for sharing your feedback.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Gap(14.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: AppColors.bgSection,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Row(
                children: <Widget>[
                  PhosphorIcon(
                    PhosphorIcons.userCircle,
                    size: 18.sp,
                    color: AppColors.textSecondary,
                  ),
                  Gap(8.w),
                  Expanded(
                    child: Text(
                      reviewerName,
                      style: AppTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    submittedAt.toIndianDateTime,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Gap(18.h),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  minimumSize: Size.fromHeight(46.h),
                ),
                child: Text(
                  'Done',
                  style: AppTextStyles.buttonLarge.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

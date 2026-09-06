import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/repositories/review_repository.dart';
import 'package:bakaloo_flutter_app/features/reviews/presentation/providers/review_provider.dart';

class WriteReviewScreen extends ConsumerStatefulWidget {
  const WriteReviewScreen({
    required this.productName,
    this.productId,
    this.orderId,
    this.reviewId,
    this.productImage,
    this.initialRating = 0,
    this.initialComment = '',
    super.key,
  });

  final String productName;
  final String? productId;
  final String? orderId;
  final String? reviewId;
  final String? productImage;
  final int initialRating;
  final String initialComment;

  bool get isEdit => reviewId != null;

  @override
  ConsumerState<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends ConsumerState<WriteReviewScreen> {
  late final TextEditingController _commentController;
  late int _rating;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating.clamp(0, 5);
    _commentController = TextEditingController(text: widget.initialComment);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating <= 0) {
      AppToast.show(context, '⚠️ Please select a rating', type: ToastType.warning);
      return;
    }

    setState(() {
      _submitting = true;
    });

    late final ReviewActionResult result;
    final comment = _commentController.text.trim().isEmpty
        ? null
        : _commentController.text.trim();

    if (widget.isEdit) {
      result = await ref.read(reviewProvider.notifier).updateReview(
            widget.reviewId!,
            ReviewUpdateParams(
              rating: _rating,
              comment: comment,
            ),
          );
    } else {
      if (widget.productId == null || widget.orderId == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _submitting = false;
        });
        AppToast.show(context, '⚠️ Review is not available for this product yet.', type: ToastType.warning);
        return;
      }

      result = await ref.read(reviewProvider.notifier).createReview(
            ReviewCreateParams(
              productId: widget.productId!,
              orderId: widget.orderId!,
              rating: _rating,
              comment: comment,
            ),
          );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
    });

    if (!result.isSuccess) {
      AppToast.show(context, result.failure!.message);
      return;
    }

    AppToast.show(context, widget.isEdit ? '✅ Review updated.' : '✅ Review submitted.', type: ToastType.success);
    Navigator.of(context).pop(true);
  }

  String get _ratingLabel => switch (_rating) {
        1 => 'Poor',
        2 => 'Fair',
        3 => 'Good',
        4 => 'Very Good',
        5 => 'Excellent!',
        _ => 'Tap a star to rate',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text(
          widget.isEdit ? 'Edit Review' : 'Write Review',
          style: AppTextStyles.h2,
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
        children: <Widget>[
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              boxShadow: const <BoxShadow>[AppShadows.cardShadow],
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 64.w,
                  height: 64.w,
                  decoration: BoxDecoration(
                    color: AppColors.bgSection,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (widget.productImage ?? '').isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.productImage!,
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
                  child: Text(
                    widget.productName,
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Gap(18.h),
          Text('Your rating', style: AppTextStyles.h3),
          Gap(12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List<Widget>.generate(5, (index) {
              final star = index + 1;
              final isSelected = star <= _rating;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _rating = star;
                  });
                },
                child: SizedBox(
                  width: 48.w,
                  height: 48.w,
                  child: Center(
                    child: AnimatedScale(
                      scale: isSelected ? 1.12 : 1,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutBack,
                      child: PhosphorIcon(
                        isSelected ? PhosphorIcons.starFill : PhosphorIcons.star,
                        size: 34.sp,
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
          Text(
            _ratingLabel,
            style: AppTextStyles.buttonMedium.copyWith(
              color: AppColors.primaryGreen,
            ),
          ),
          Gap(20.h),
          Text('Comment (optional)', style: AppTextStyles.h3),
          Gap(8.h),
          SizedBox(
            height: 120.h,
            child: TextField(
              controller: _commentController,
              maxLength: 500,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Share your experience...',
                alignLabelWithHint: true,
              ),
            ),
          ),
          Gap(18.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                minimumSize: Size.fromHeight(50.h),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      widget.isEdit ? 'Update Review' : 'Submit Review',
                      style: AppTextStyles.buttonLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

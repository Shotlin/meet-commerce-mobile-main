import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/coupon_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/checkout_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/coupon_provider.dart';

// ─── Colour tokens (matches cart_offers_section.dart's palette) ─────────────
const _kSheetBg = Color(0xFFF4F6F8);
const _kCardBg = Colors.white;
const _kGreen = Color(0xFF0AC26B);
const _kGreenLight = Color(0xFFE7FBF1);
const _kBorder = Color(0xFFE8ECF0);
const _kDash = Color(0xFFDDE1E6);
const _kLocked = Color(0xFFF0F2F5);
const _kLockedFg = Color(0xFF9AA3B0);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B7280);
const _kAmber = Color(0xFFE07800);

/// Opens the cart's "Apply Coupon" flow as a premium modal bottom sheet —
/// replaces the old push-to-[CouponsScreen] navigation. Same underlying
/// data/actions as the full-page version (`availableCouponsProvider`,
/// `checkoutProvider.applyCoupon/removeCoupon`) — this only ever reuses that
/// flow, it does not duplicate coupon business logic.
Future<void> showCartCouponSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const CartCouponSheet(),
  );
}

class CartCouponSheet extends ConsumerStatefulWidget {
  const CartCouponSheet({super.key});

  @override
  ConsumerState<CartCouponSheet> createState() => _CartCouponSheetState();
}

class _CartCouponSheetState extends ConsumerState<CartCouponSheet> {
  final TextEditingController _codeController = TextEditingController();
  final Set<String> _expandedTerms = <String>{};

  /// The code currently being validated (manual entry or a card's own Apply
  /// button) — disables every Apply affordance while a request is in
  /// flight so a double-tap can't fire two validations at once.
  String? _applyingCode;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _applyCode(String rawCode) async {
    final normalized = rawCode.trim().toUpperCase();
    if (normalized.isEmpty || _applyingCode != null) return;

    setState(() => _applyingCode = normalized);
    final success =
        await ref.read(checkoutProvider.notifier).applyCoupon(normalized);
    if (!mounted) return;

    setState(() => _applyingCode = null);

    if (success) {
      FocusScope.of(context).unfocus();
      AppToast.show(context, '$normalized applied successfully.');
      Navigator.of(context).pop();
      return;
    }

    final error = ref.read(checkoutProvider).errorMessage;
    ref.read(checkoutProvider.notifier).clearError();
    if (error != null && mounted) {
      AppToast.show(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaHeight = MediaQuery.of(context).size.height;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          constraints: BoxConstraints(maxHeight: mediaHeight * 0.92),
          decoration: const BoxDecoration(
            color: _kSheetBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: <Widget>[
              Gap(10.h),
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(99.r),
                ),
              ),
              _buildHeader(context),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
                  children: <Widget>[
                    _buildManualEntry(context),
                    Gap(16.h),
                    _buildAppliedBanner(),
                    _buildCouponList(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 8.w, 6.h),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Apply Coupon',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 19.sp,
                fontWeight: FontWeight.w800,
                color: _kTextPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close_rounded, size: 22.sp, color: _kTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildManualEntry(BuildContext context) {
    final isApplying = _applyingCode != null;
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _kBorder),
      ),
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 6.w, 4.h),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
              enabled: !isApplying,
              onSubmitted: _applyCode,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.5.sp,
                fontWeight: FontWeight.w700,
                color: _kTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Enter Coupon Code',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.5.sp,
                  fontWeight: FontWeight.w500,
                  color: _kTextSecondary,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          TextButton(
            onPressed: isApplying ? null : () => _applyCode(_codeController.text),
            style: TextButton.styleFrom(
              foregroundColor: _kGreen,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            ),
            child: (isApplying && _applyingCode == _codeController.text.trim().toUpperCase())
                ? SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: const CircularProgressIndicator(strokeWidth: 2, color: _kGreen),
                  )
                : Text(
                    'Apply',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: _kGreen,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppliedBanner() {
    final appliedCoupon = ref.watch(
      checkoutProvider.select((s) => s.appliedCoupon),
    );
    if (appliedCoupon == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: _kGreenLight,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: _kGreen.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.check_circle_rounded, color: _kGreen, size: 20.sp),
            Gap(10.w),
            Expanded(
              child: Text(
                '${appliedCoupon.code} applied to this order',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: _kGreen,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => ref.read(checkoutProvider.notifier).removeCoupon(),
              child: Text(
                'Remove',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w700,
                  color: _kTextSecondary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponList() {
    final couponsAsync = ref.watch(availableCouponsProvider);
    final appliedCode = ref.watch(
      checkoutProvider.select((s) => s.appliedCoupon?.code),
    );
    final cart = ref.watch(checkoutProvider.notifier).cart;
    final subtotal = ref.watch(checkoutProvider.notifier).subtotal;

    return couponsAsync.when(
      loading: () => Column(
        children: List<Widget>.generate(
          2,
          (_) => Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: _SkeletonCouponCard(),
          ),
        ),
      ),
      error: (_, __) => _MessageCard(
        icon: Icons.error_outline_rounded,
        message: 'Unable to load coupons right now.',
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(availableCouponsProvider),
      ),
      data: (coupons) {
        if (coupons.isEmpty) {
          return const _MessageCard(
            icon: Icons.local_offer_outlined,
            message: 'No live coupons right now. Try a code manually.',
          );
        }

        return Column(
          children: <Widget>[
            for (final coupon in coupons)
              Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: _CouponTicketCard(
                  coupon: coupon,
                  isApplied: appliedCode == coupon.code,
                  isApplying: _applyingCode == coupon.code,
                  eligibility: _eligibilityFor(coupon, cart, subtotal),
                  isTermsExpanded: _expandedTerms.contains(coupon.code),
                  onToggleTerms: () => setState(() {
                    if (_expandedTerms.contains(coupon.code)) {
                      _expandedTerms.remove(coupon.code);
                    } else {
                      _expandedTerms.add(coupon.code);
                    }
                  }),
                  onApply: () => _applyCode(coupon.code),
                  onRemove: () =>
                      ref.read(checkoutProvider.notifier).removeCoupon(),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─── Eligibility ─────────────────────────────────────────────────────────

class _CouponEligibility {
  const _CouponEligibility({required this.eligible, this.message});

  final bool eligible;
  final String? message;
}

/// Local, data-driven eligibility check — mirrors
/// `CheckoutNotifier._couponStillMatchesCart`'s scope logic so the
/// shortfall message this sheet shows is always consistent with what the
/// backend will actually accept, with no extra network round trip.
_CouponEligibility _eligibilityFor(
  CouponEntity coupon,
  CartEntity cart,
  double subtotal,
) {
  final productIds = coupon.applicableProductIds;
  final categoryIds = coupon.applicableCategoryIds;
  final hasProductScope = productIds != null && productIds.isNotEmpty;
  final hasCategoryScope = categoryIds != null && categoryIds.isNotEmpty;
  final hasScope = hasProductScope || hasCategoryScope;

  double base;
  if (hasScope) {
    final productSet = hasProductScope ? productIds.toSet() : const <String>{};
    final categorySet =
        hasCategoryScope ? categoryIds.toSet() : const <String>{};
    base = cart.items
        .where(
          (item) =>
              productSet.contains(item.productId) ||
              (item.categoryId != null &&
                  categorySet.contains(item.categoryId)),
        )
        .fold<double>(0, (sum, item) => sum + item.total);
  } else {
    base = subtotal;
  }

  if (base >= coupon.minOrderAmount) {
    return const _CouponEligibility(eligible: true);
  }

  if (hasScope && base <= 0) {
    return _CouponEligibility(
      eligible: false,
      message:
          'Add min 1 eligible item(s) worth ${coupon.minOrderAmount.toInrCurrency} to avail this offer.',
    );
  }

  final shortfall = coupon.minOrderAmount - base;
  return _CouponEligibility(
    eligible: false,
    message:
        'Add items worth ${shortfall.toInrCurrency} more to avail this offer.',
  );
}

// ─── Ticket-style coupon card ────────────────────────────────────────────

class _CouponTicketCard extends StatelessWidget {
  const _CouponTicketCard({
    required this.coupon,
    required this.isApplied,
    required this.isApplying,
    required this.eligibility,
    required this.isTermsExpanded,
    required this.onToggleTerms,
    required this.onApply,
    required this.onRemove,
  });

  final CouponEntity coupon;
  final bool isApplied;
  final bool isApplying;
  final _CouponEligibility eligibility;
  final bool isTermsExpanded;
  final VoidCallback onToggleTerms;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  String get _title {
    final description = coupon.description?.trim();
    if (description != null && description.isNotEmpty) {
      return description;
    }
    switch (coupon.discountType) {
      case CouponDiscountType.PERCENTAGE:
        final maxPart =
            coupon.maxDiscount > 0 ? ' up to ${coupon.maxDiscount.toInrCurrency}' : '';
        return '${coupon.discountValue.toStringAsFixed(0)}% discount$maxPart';
      case CouponDiscountType.FLAT:
        return '${coupon.discountValue.toInrCurrency} off on your order';
      case CouponDiscountType.CASHBACK:
        final maxPart =
            coupon.maxDiscount > 0 ? ' up to ${coupon.maxDiscount.toInrCurrency}' : '';
        return '${coupon.discountValue.toStringAsFixed(0)}% cashback$maxPart';
      case CouponDiscountType.FREE_DELIVERY:
        return 'Free delivery on your order';
    }
  }

  IconData get _badgeIcon {
    if (isApplied) return Icons.check_rounded;
    if (coupon.discountType == CouponDiscountType.FREE_DELIVERY ||
        coupon.freeDelivery) {
      return Icons.local_shipping_outlined;
    }
    if (coupon.discountType == CouponDiscountType.CASHBACK) {
      return Icons.currency_rupee_rounded;
    }
    return Icons.percent_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final eligible = eligibility.eligible;
    final titleColor = (eligible || isApplied) ? _kTextPrimary : _kLockedFg;

    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isApplied ? _kGreen.withValues(alpha: 0.55) : _kBorder,
          width: isApplied ? 1.4 : 1.0,
        ),
      ),
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: isApplied
                      ? _kGreen
                      : eligible
                          ? _kGreenLight
                          : _kLocked,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _badgeIcon,
                  size: 16.sp,
                  color: isApplied
                      ? Colors.white
                      : eligible
                          ? _kGreen
                          : _kLockedFg,
                ),
              ),
              Gap(10.w),
              Expanded(
                child: Text(
                  _title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    height: 1.3,
                  ),
                ),
              ),
              Gap(8.w),
              _CardTrailingAction(
                isApplied: isApplied,
                isEligible: eligible,
                isApplying: isApplying,
                onApply: onApply,
                onRemove: onRemove,
              ),
            ],
          ),
          if (!isApplied && eligibility.message != null) ...<Widget>[
            Gap(6.h),
            Padding(
              padding: EdgeInsets.only(left: 42.w),
              child: Text(
                eligibility.message!,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: _kAmber,
                ),
              ),
            ),
          ],
          Gap(14.h),
          const _NotchedDashedDivider(),
          Gap(10.h),
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Row(
              children: <Widget>[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: _kLocked,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    coupon.code,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: _kTextPrimary,
                    ),
                  ),
                ),
                const Spacer(),
                if (coupon.terms != null && coupon.terms!.trim().isNotEmpty)
                  InkWell(
                    onTap: onToggleTerms,
                    borderRadius: BorderRadius.circular(8.r),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'T&C',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.w700,
                              color: _kTextSecondary,
                            ),
                          ),
                          Icon(
                            isTermsExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18.sp,
                            color: _kTextSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: isTermsExpanded
                ? Padding(
                    padding: EdgeInsets.only(bottom: 14.h),
                    child: Text(
                      coupon.terms ?? '',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: _kTextSecondary,
                        height: 1.45,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _CardTrailingAction extends StatelessWidget {
  const _CardTrailingAction({
    required this.isApplied,
    required this.isEligible,
    required this.isApplying,
    required this.onApply,
    required this.onRemove,
  });

  final bool isApplied;
  final bool isEligible;
  final bool isApplying;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (isApplied) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            'Applied',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: _kGreen,
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Text(
              'Remove',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w700,
                color: _kTextSecondary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      );
    }

    if (isApplying) {
      return SizedBox(
        width: 16.w,
        height: 16.w,
        child: const CircularProgressIndicator(strokeWidth: 2, color: _kGreen),
      );
    }

    return GestureDetector(
      onTap: isEligible ? onApply : null,
      child: Text(
        'Apply',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14.sp,
          fontWeight: FontWeight.w800,
          color: isEligible ? _kGreen : _kLockedFg,
        ),
      ),
    );
  }
}

/// A dashed horizontal divider with two small semicircle "notches" cut into
/// the sheet background colour at each end — the ticket-stub look from the
/// reference, done with plain widgets (no custom clipping/layout math)
/// since the divider row's own bounds already fix where the notches sit.
class _NotchedDashedDivider extends StatelessWidget {
  const _NotchedDashedDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 14,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          _DashedLine(),
          Positioned(left: -20, child: _Notch()),
          Positioned(right: -20, child: _Notch()),
        ],
      ),
    );
  }
}

class _Notch extends StatelessWidget {
  const _Notch();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: const BoxDecoration(
        color: _kSheetBg,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 5.0;
        const dashSpace = 4.0;
        final count = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List<Widget>.generate(
            count,
            (_) => Container(width: dashWidth, height: 1, color: _kDash),
          ),
        );
      },
    );
  }
}

// ─── Skeleton / message cards ─────────────────────────────────────────────

class _SkeletonCouponCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96.h,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _kBorder),
      ),
      padding: EdgeInsets.all(14.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 32.w,
            height: 32.w,
            decoration: const BoxDecoration(
              color: AppColors.bgSkeleton,
              shape: BoxShape.circle,
            ),
          ),
          Gap(10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: double.infinity,
                  height: 13.h,
                  decoration: BoxDecoration(
                    color: AppColors.bgSkeleton,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                ),
                Gap(8.h),
                Container(
                  width: 140.w,
                  height: 11.h,
                  decoration: BoxDecoration(
                    color: AppColors.bgSkeleton,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 26.h),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 26.sp, color: _kTextSecondary),
          Gap(10.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: _kTextSecondary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            Gap(12.h),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _kGreen),
                foregroundColor: _kGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

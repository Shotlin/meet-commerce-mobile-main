import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/products/data/models/product_options_response.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/providers/product_options_provider.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';

/// Pale surface behind the option rows (reference uses a very light grey so
/// the white option cards stand out).
const Color _sheetSurface = Color(0xFFF6F6F8);

class ProductOptionBottomSheet extends ConsumerWidget {
  const ProductOptionBottomSheet({
    required this.product,
    super.key,
  });

  final ProductEntity product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optionsAsync = ref.watch(productOptionsProvider(product.id));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      decoration: BoxDecoration(
        color: _sheetSurface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22.r),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildHandle(),
          optionsAsync.when(
            loading: () => _buildLoading(),
            error: (error, _) => _buildError(context, ref, error),
            data: (response) => _buildContent(context, ref, response),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: EdgeInsets.only(top: 12.h, bottom: 8.h),
      child: Center(
        child: Container(
          width: 44.w,
          height: 4.h,
          decoration: BoxDecoration(
            color: const Color(0xFFD8D8DE),
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
      child: Column(
        children: List.generate(
          3,
          (_) => Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Container(
              height: 76.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object error) {
    return Padding(
      padding: EdgeInsets.all(28.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PhosphorIcon(
            PhosphorIcons.warningCircle,
            size: 40.sp,
            color: AppColors.textTertiary,
          ),
          Gap(12.h),
          Text(
            'Unable to load options',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Gap(16.h),
          OutlinedButton(
            onPressed: () => ref.invalidate(productOptionsProvider(product.id)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
              side: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: Text(
              'Retry',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ProductOptionsResponse response,
  ) {
    final familyName =
        response.family?.name ?? product.familyName ?? product.name;
    final subtitle = product.categoryName?.trim();

    if (response.options.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 40.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PhosphorIcon(
              PhosphorIcons.package,
              size: 40.sp,
              color: AppColors.textTertiary,
            ),
            Gap(12.h),
            Text(
              'No options available',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ── Family title + optional subtitle ─────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(18.w, 2.h, 18.w, 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  familyName,
                  style: AppTextStyles.h3.copyWith(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...<Widget>[
                  Gap(2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 20.h),
              itemCount: response.options.length,
              separatorBuilder: (_, __) => Gap(12.h),
              itemBuilder: (context, index) {
                final option = response.options[index];
                return _OptionRow(option: option);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionRow extends ConsumerWidget {
  const _OptionRow({required this.option});

  final ProductOptionItem option;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(cartItemQuantityProvider(option.id));
    final isDisabled = !option.inStock;

    return Opacity(
      opacity: isDisabled ? 0.55 : 1.0,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: const Color(0xFFEDEDED)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            // ── Image + label/price — tapping this opens the product page.
            // Kept out of the trailing ADD/stepper's tap area so adding to
            // cart and navigating to the detail page can't both fire off a
            // single tap.
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14.r),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/product/${option.id}');
                },
                child: Row(
                  children: <Widget>[
                    _OptionThumb(option: option),
                    Gap(12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              if (option.hasFoodMarker) ...<Widget>[
                                _FoodMarkerDot(option: option),
                                Gap(5.w),
                              ],
                              Expanded(
                                child: Text(
                                  option.displayUnit,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Gap(6.h),
                          _PriceRow(option: option),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Gap(12.w),
            // ── ADD / stepper ───────────────────────────────────────────
            if (!isDisabled)
              _CartActionButton(option: option, quantity: quantity)
            else
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F2),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  'Sold out',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Option thumbnail with a discount burst badge overlaid on the image
/// (matches the reference "6% OFF" / "5% OFF" tag).
class _OptionThumb extends StatelessWidget {
  const _OptionThumb({required this.option});

  final ProductOptionItem option;

  @override
  Widget build(BuildContext context) {
    final discount = option.discountPercent;
    final showBadge = option.salePrice != null &&
        option.salePrice! < option.price &&
        discount > 0;

    return SizedBox(
      width: 60.w,
      height: 60.w,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: SizedBox(
              width: 60.w,
              height: 60.w,
              child: option.thumbnailUrl != null
                  ? AppImage(
                      imageUrl: option.thumbnailUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 120,
                      memCacheHeight: 120,
                    )
                  : Container(
                      color: const Color(0xFFF5F5F5),
                      child: Icon(
                        Icons.image_outlined,
                        size: 22.sp,
                        color: AppColors.textDisabled,
                      ),
                    ),
            ),
          ),
          if (showBadge)
            Positioned(
              top: -4.h,
              left: -4.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFD02428),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  '$discount%\nOFF',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.05,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FoodMarkerDot extends StatelessWidget {
  const _FoodMarkerDot({required this.option});

  final ProductOptionItem option;

  @override
  Widget build(BuildContext context) {
    final color = option.isVeg
        ? AppColors.vegGreen
        : option.isNonVeg
            ? AppColors.nonVegRed
            : const Color(0xFFF9A825);

    return Container(
      width: 14.w,
      height: 14.w,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2.r),
        border: Border.all(color: color, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 6.w,
        height: 6.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.option});

  final ProductOptionItem option;

  @override
  Widget build(BuildContext context) {
    final isOnSale =
        option.salePrice != null && option.salePrice! < option.price;

    return Row(
      children: <Widget>[
        Text(
          '₹${option.effectivePrice.toInt()}',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        if (isOnSale) ...<Widget>[
          Gap(6.w),
          Text(
            '₹${option.price.toInt()}',
            style: TextStyle(
              fontSize: 12.sp,
              color: AppColors.textTertiary,
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

class _CartActionButton extends ConsumerWidget {
  const _CartActionButton({
    required this.option,
    required this.quantity,
  });

  final ProductOptionItem option;
  final int quantity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (quantity > 0) {
      return _QuantityStepper(option: option, quantity: quantity);
    }

    return SizedBox(
      height: 38.h,
      width: 92.w,
      child: OutlinedButton(
        onPressed: () async {
          final result = await ref.read(cartProvider.notifier).addItem(
                option.id,
                1,
                shopProductId: option.shopProductId,
              );
          if (!context.mounted || result.isSuccess) return;
          AppToast.show(context, result.failure!.message);
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primaryGreen,
          side: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9.r),
          ),
        ),
        child: Text(
          'ADD',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _QuantityStepper extends ConsumerWidget {
  const _QuantityStepper({
    required this.option,
    required this.quantity,
  });

  final ProductOptionItem option;
  final int quantity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 38.h,
      width: 92.w,
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(9.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _StepperButton(
            icon: PhosphorIcons.minus,
            onTap: () async {
              if (quantity == 1) {
                final result = await ref.read(cartProvider.notifier).removeItem(
                      option.id,
                      shopProductId: option.shopProductId,
                    );
                if (!context.mounted || result.isSuccess) return;
                AppToast.show(context, result.failure!.message);
                return;
              }
              final result = await ref.read(cartProvider.notifier).updateItem(
                    option.id,
                    quantity - 1,
                    shopProductId: option.shopProductId,
                  );
              if (!context.mounted || result.isSuccess) return;
              AppToast.show(context, result.failure!.message);
            },
          ),
          Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14.sp,
            ),
          ),
          _StepperButton(
            icon: PhosphorIcons.plus,
            onTap: () async {
              if (quantity >= (option.maxOrderQty ?? 50)) {
                AppToast.show(
                  context,
                  '⚠️ Maximum ${option.maxOrderQty ?? 50} items allowed per order',
                  type: ToastType.warning,
                );
                return;
              }
              final result = await ref.read(cartProvider.notifier).updateItem(
                    option.id,
                    quantity + 1,
                    shopProductId: option.shopProductId,
                  );
              if (!context.mounted || result.isSuccess) return;
              AppToast.show(context, result.failure!.message);
            },
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 30.w,
        height: 38.h,
        child: Center(
          child: PhosphorIcon(
            icon,
            size: 15,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

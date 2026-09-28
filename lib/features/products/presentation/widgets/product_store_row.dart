import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/providers/product_store_info_provider.dart';

/// Compact "Sold by {store}" row shown on the product detail screen.
///
///   Available:    Sold by SANDI STORE — Available for delivery to 743287
///   Unavailable:  Sold by SANDI STORE — Not available for delivery to 743287
///
/// A neutral panel (not a green-tinted one) with the brand red as the store
/// icon's accent — matching ProductDeliveryBanner right above it. Only the
/// one line that's genuinely a status ("Available"/"Not available") keeps a
/// semantic color, as a small icon+text accent rather than the whole card.
class ProductStoreRow extends ConsumerWidget {
  const ProductStoreRow({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productStoreInfoProvider(productId));

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (store) {
        if (store == null || !store.hasStore) {
          return const SizedBox.shrink();
        }

        final available = store.isAvailableAtSelectedLocation;
        final pincode = store.selectedPincode;

        // Small status accent (icon + text only) — the card itself stays
        // neutral regardless of state.
        final statusColor = available ? AppColors.successGreen : AppColors.warningOrange;

        final String availabilityText;
        if (available) {
          availabilityText = pincode != null
              ? 'Available for delivery to $pincode'
              : 'Available for delivery';
        } else if (store.availabilityReason == 'PRODUCT_OUT_OF_STOCK') {
          availabilityText = 'Currently out of stock at ${store.shopName}';
        } else {
          availabilityText = pincode != null
              ? 'Not available for delivery to $pincode'
              : 'Not available for delivery to your location';
        }

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: AppColors.bgSection,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 34.w,
                height: 34.w,
                decoration: const BoxDecoration(
                  color: AppColors.brandRed,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIcons.storefrontFill,
                  size: 18.sp,
                  color: Colors.white,
                ),
              ),
              Gap(10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          'Sold by ',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            store.shopName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Gap(3.h),
                    Row(
                      children: <Widget>[
                        Icon(
                          available
                              ? PhosphorIcons.checkCircleFill
                              : PhosphorIcons.warningCircleFill,
                          size: 13.sp,
                          color: statusColor,
                        ),
                        Gap(4.w),
                        Expanded(
                          child: Text(
                            availabilityText,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

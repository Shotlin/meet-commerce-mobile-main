import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/location/presentation/providers/guest_storefront_provider.dart';
import 'package:bakaloo_flutter_app/features/location/presentation/widgets/location_prompt_sheet.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/routing/app_router.dart';
import 'package:bakaloo_flutter_app/shared/utils/address_utils.dart';
import 'package:bakaloo_flutter_app/shared/widgets/address_bottom_sheet.dart';

/// Compact delivery context displayed on the product page. It uses the
/// active customer or guest location already resolved for storefront pricing.
///
/// Deliberately a neutral panel with the brand red as a small icon accent —
/// not a green/tinted card. This isn't a status ("available"/"unavailable")
/// the way ProductStoreRow's badge is; it's the same plain informational
/// line for every product, so it doesn't need — or deserve — a decorative
/// color treatment of its own.
class ProductDeliveryBanner extends ConsumerWidget {
  const ProductDeliveryBanner({required this.product, super.key});

  final ProductEntity product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final List<AddressEntity>? addresses =
        currentUser == null ? null : ref.watch(addressProvider).asData?.value;
    final guestLocation =
        currentUser == null ? ref.watch(guestStorefrontProvider) : null;
    final addressText = resolveAddressLabel(
      isLoggedIn: currentUser != null,
      addresses: addresses,
      guestAddressLine1: guestLocation?.addressLine1,
      guestCity: guestLocation?.city,
      guestPincode: guestLocation?.pincode,
    );
    final etaText = product.hasDeliveryTime
        ? 'Fresh delivery in ${product.formattedDeliveryTime}'
        : 'Fresh delivery, fast';

    void changeLocation() {
      if (currentUser == null) {
        showLocationPromptSheet(context, guestStorefront: true);
      } else {
        showAddressSheet(context);
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.bgSection,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: const BoxDecoration(
                    color: AppColors.brandRed,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: PhosphorIcon(
                      PhosphorIcons.truckBold,
                      size: 18.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Get it delivered fresh',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        etaText,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 11.h),
              child: const Divider(height: 1, color: AppColors.borderLight),
            ),
            InkWell(
              onTap: changeLocation,
              borderRadius: BorderRadius.circular(8.r),
              child: Row(
                children: <Widget>[
                  PhosphorIcon(
                    PhosphorIcons.mapPinFill,
                    size: 16.sp,
                    color: AppColors.brandRed,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      addressText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Change',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandRed,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 17.sp,
                    color: AppColors.brandRed,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

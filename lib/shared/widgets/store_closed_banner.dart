import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/store_status_provider.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';

/// "We are closed" banner — shown on the home screen directly below the
/// search bar (and above the category tabs) whenever the store is closed,
/// driven entirely by the admin-uploaded image on the Store Hours settings
/// page (bakaloo-backend migration 075). Renders nothing when the store is
/// open or no image has ever been uploaded, so it never appears
/// unexpectedly on stores that haven't configured one.
///
/// The vertical breathing room below is only ever applied here, inside the
/// "actually showing a banner" branch — a wrapping Padding at the call site
/// in home_screen.dart would reserve that space even while this renders
/// SizedBox.shrink() (store open / no banner configured), leaving a blank
/// gap sitting between the search bar and category tabs for no reason.
class StoreClosedBanner extends ConsumerWidget {
  const StoreClosedBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(storeStatusProvider).asData?.value;
    final imageUrl = status?.closedBannerImageUrl;
    if (status == null || status.isOpen || imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    // customBanner uses Cloudinary crop='fit' (scale to fit within bounds,
    // never crop) — unlike the 'banner' profile (crop='fill'), which crops
    // the image server-side to a fixed box before it even reaches the
    // phone, making any local BoxFit choice irrelevant.
    final optimizedImage = ApiConstants.optimizedMedia(
      imageUrl,
      profile: CustomerImageProfile.customBanner,
    );

    // Full device width, no side gaps, no rounded corners. BoxFit.fitWidth
    // with no forced aspect ratio/height lets the image size itself to its
    // own real proportions scaled to fill the width — nothing gets cropped
    // regardless of what shape the admin's uploaded banner actually is.
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: SizedBox(
        width: double.infinity,
        child: AppImage(
          imageUrl: optimizedImage.url ?? imageUrl,
          fit: BoxFit.fitWidth,
          memCacheWidth: optimizedImage.memCacheWidth,
          memCacheHeight: optimizedImage.memCacheHeight,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';

/// Small thumbnail row beneath the hero gallery — tapping one jumps the
/// hero PageView to that image.
class ProductThumbnailStrip extends StatelessWidget {
  const ProductThumbnailStrip({
    required this.images,
    required this.selectedIndex,
    required this.onSelect,
    super.key,
  });

  final List<String> images;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    if (images.length < 2) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 12.h),
      child: SizedBox(
        height: 64.w,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: images.length,
          separatorBuilder: (_, __) => SizedBox(width: 10.w),
          itemBuilder: (context, index) {
            final isSelected = index == selectedIndex;
            return GestureDetector(
              onTap: () => onSelect(index),
              child: Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.brandRed
                        : const Color(0xFFE5E5E5),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: CachedNetworkImage(
                  imageUrl: images[index],
                  fit: BoxFit.cover,
                  memCacheWidth: 192,
                  memCacheHeight: 192,
                  fadeInDuration: Duration.zero,
                  placeholder: (context, url) =>
                      const ColoredBox(color: Color(0xFFF2F2F2)),
                  errorWidget: (context, url, error) => const ColoredBox(
                    color: Color(0xFFF2F2F2),
                    child: Center(
                      child: PhosphorIcon(
                        PhosphorIcons.image,
                        color: Color(0xFFBBBBBB),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

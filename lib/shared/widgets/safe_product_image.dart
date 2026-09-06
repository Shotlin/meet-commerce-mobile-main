import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';

/// Returns `true` when [url] is a non-empty absolute `http(s)` URL with a host.
///
/// Treating image URLs as untrusted input prevents malformed or non-network
/// schemes (e.g. `file://`, `javascript:`) from reaching the image pipeline.
bool isSafeImageUrl(String? url) {
  if (url == null) {
    return false;
  }
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
    return false;
  }
  return uri.scheme == 'https' || uri.scheme == 'http';
}

/// A defensive, cached product image with consistent placeholder/error states.
///
/// Validates the URL before handing it to [CachedNetworkImage] and renders a
/// neutral fallback for missing/invalid images so order cards never break.
class SafeProductImage extends StatelessWidget {
  const SafeProductImage({
    required this.url,
    required this.size,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.backgroundColor,
    this.iconSize,
    super.key,
  });

  final String? url;
  final double size;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final Color? backgroundColor;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(12.r);
    final bg = backgroundColor ?? AppColors.orderThumbBg;
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
    final cacheWidth = (size * dpr).round();

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size,
        height: size,
        child: isSafeImageUrl(url)
            ? CachedNetworkImage(
                imageUrl: url!.trim(),
                fit: fit,
                memCacheWidth: cacheWidth,
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (_, __) => ColoredBox(color: bg),
                errorWidget: (_, __, ___) => _Fallback(bg: bg, size: iconSize),
              )
            : _Fallback(bg: bg, size: iconSize),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.bg, this.size});

  final Color bg;
  final double? size;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: bg,
      child: Center(
        child: PhosphorIcon(
          PhosphorIcons.package,
          size: size ?? 18.sp,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

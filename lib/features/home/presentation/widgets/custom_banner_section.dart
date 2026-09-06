import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/shared/utils/link_tap_handler.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';

class CustomBannerSection extends StatefulWidget {
  const CustomBannerSection({
    required this.imageUrl,
    super.key,
    this.linkUrl,
    this.borderRadius = 16,
    this.aspectRatio,
  });

  final String? imageUrl;
  final String? linkUrl;
  final double borderRadius;
  final double? aspectRatio;

  @override
  State<CustomBannerSection> createState() => _CustomBannerSectionState();
}

class _CustomBannerSectionState extends State<CustomBannerSection> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  double? _resolvedAspectRatio;

  @override
  void initState() {
    super.initState();
    _syncAspectRatio();
  }

  @override
  void didUpdateWidget(covariant CustomBannerSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _syncAspectRatio();
    }
  }

  @override
  void dispose() {
    _detachImageStream();
    super.dispose();
  }

  void _syncAspectRatio() {
    _detachImageStream();
    _resolvedAspectRatio = null;

    final resolvedImage = ApiConstants.proxiedOptimizedMedia(
      widget.imageUrl,
      profile: CustomerImageProfile.customBanner,
    );
    final String? url = resolvedImage.url ?? widget.imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return;
    }

    final ImageProvider provider = CachedNetworkImageProvider(
      url,
      maxWidth: resolvedImage.memCacheWidth,
      maxHeight: resolvedImage.memCacheHeight,
    );
    final ImageStream stream = provider.resolve(const ImageConfiguration());
    _imageStream = stream;

    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo image, bool _) {
        final double width = image.image.width.toDouble();
        final double height = image.image.height.toDouble();
        final double nextAspectRatio =
            height > 0 ? width / height : (16 / 9);
        if (mounted) {
          setState(() {
            _resolvedAspectRatio = nextAspectRatio;
          });
        }
        stream.removeListener(listener);
        if (identical(_imageStream, stream)) {
          _imageStream = null;
          _imageStreamListener = null;
        }
      },
      onError: (_, __) {
        stream.removeListener(listener);
        if (identical(_imageStream, stream)) {
          _imageStream = null;
          _imageStreamListener = null;
        }
      },
    );

    _imageStreamListener = listener;
    stream.addListener(listener);
  }

  void _detachImageStream() {
    if (_imageStream != null && _imageStreamListener != null) {
      _imageStream!.removeListener(_imageStreamListener!);
    }
    _imageStream = null;
    _imageStreamListener = null;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedImage = ApiConstants.proxiedOptimizedMedia(
      widget.imageUrl,
      profile: CustomerImageProfile.customBanner,
    );
    final double effectiveAspectRatio =
        widget.aspectRatio ?? _resolvedAspectRatio ?? (16 / 9);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      child: GestureDetector(
        onTap: widget.linkUrl == null || widget.linkUrl!.trim().isEmpty
            ? null
            : () => handleLinkTap(context, widget.linkUrl!.trim()),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius.r),
          child: AspectRatio(
            aspectRatio:
                effectiveAspectRatio <= 0 ? (16 / 9) : effectiveAspectRatio,
            child: widget.imageUrl == null || widget.imageUrl!.trim().isEmpty
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      border: Border.all(
                        color: const Color(0xFFD9D9D9),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: PhosphorIcon(
                        PhosphorIcons.imageSquareDuotone,
                        size: 42.sp,
                        color: const Color(0xFF9B9B9B),
                      ),
                    ),
                  )
                : AppImage(
                    imageUrl: resolvedImage.url ?? widget.imageUrl!,
                    memCacheWidth: resolvedImage.memCacheWidth,
                    memCacheHeight: resolvedImage.memCacheHeight,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    placeholder: const ColoredBox(
                      color: Colors.white,
                      child: SizedBox.expand(),
                    ),
                    errorWidget: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                      ),
                      child: Center(
                        child: PhosphorIcon(
                          PhosphorIcons.imageBrokenDuotone,
                          size: 38.sp,
                          color: const Color(0xFF9B9B9B),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

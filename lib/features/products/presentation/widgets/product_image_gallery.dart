import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_highlights_overlay.dart';

class ProductImageGallery extends StatefulWidget {
  const ProductImageGallery({
    required this.images,
    required this.productName,
    required this.price,
    required this.avgRating,
    required this.ratingCount,
    required this.isCollapsed,
    required this.isWishlisted,
    required this.onWishlistToggle,
    this.pageController,
    this.thumbnailUrl,
    this.salePrice,
    this.highlights,
    this.onSearch,
    this.onShare,
    this.onBack,
    this.onImageChanged,
    this.onHighlightsToggle,
    super.key,
  });

  final List<String> images;
  final String? thumbnailUrl;
  final String productName;
  final double price;
  final double? salePrice;
  final double avgRating;
  final int ratingCount;
  final Map<String, dynamic>? highlights;
  final bool isCollapsed;
  final bool isWishlisted;
  final VoidCallback onWishlistToggle;
  // Owned by the parent screen when provided (so a thumbnail strip can
  // command page changes too) — this widget creates and owns its own
  // otherwise, unchanged from before.
  final PageController? pageController;
  final VoidCallback? onSearch;
  final VoidCallback? onShare;
  final VoidCallback? onBack;
  final ValueChanged<int>? onImageChanged;
  final VoidCallback? onHighlightsToggle;

  @override
  State<ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<ProductImageGallery> {
  late final PageController _pageController;
  bool _ownsController = false;
  bool _showHighlights = false;

  List<String> get _galleryImages {
    final filtered = widget.images.where((image) => image.isNotEmpty).toList();
    if (filtered.isNotEmpty) {
      return filtered;
    }
    if ((widget.thumbnailUrl ?? '').isNotEmpty) {
      return <String>[widget.thumbnailUrl!];
    }
    return const <String>[];
  }

  bool get _isOnSale =>
      widget.salePrice != null &&
      widget.salePrice! > 0 &&
      widget.salePrice! < widget.price;

  double get _displayPrice => _isOnSale ? widget.salePrice! : widget.price;

  String? get _thumbnailImage {
    if ((widget.thumbnailUrl ?? '').isNotEmpty) {
      return widget.thumbnailUrl;
    }
    if (_galleryImages.isNotEmpty) {
      return _galleryImages.first;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.pageController != null) {
      _pageController = widget.pageController!;
    } else {
      _pageController = PageController();
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _pageController.dispose();
    }
    super.dispose();
  }

  void _toggleHighlights() {
    final willShow = !_showHighlights;
    setState(() {
      _showHighlights = willShow;
    });
    if (willShow) {
      widget.onHighlightsToggle?.call();
    }
  }

  /// Decode target for the hero gallery image, in physical pixels. This
  /// image renders full-screen-width (StackFit.expand inside a SliverAppBar
  /// whose expandedHeight is ~420 logical px) — a fixed 520x520 cache size
  /// meant for something list-thumbnail-sized was forcing Flutter to
  /// upscale a 520px-decoded bitmap to fill a ~1000px+ physical area on
  /// most phones, which is what read as "low quality" on the detail page.
  /// Sizing to the device's actual physical width fixes that without
  /// decoding arbitrarily large admin-uploaded originals at full size.
  int _decodeDimension(BuildContext context) {
    final mq = MediaQuery.of(context);
    return (mq.size.width * mq.devicePixelRatio).round();
  }

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 382.h,
      automaticallyImplyLeading: false,
      backgroundColor:
          widget.isCollapsed ? const Color(0xFFFFFFFF) : Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      toolbarHeight: 56.h,
      title: widget.isCollapsed ? _buildCollapsedBar() : null,
      flexibleSpace: widget.isCollapsed
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color.fromRGBO(0, 0, 0, 0.06),
                    blurRadius: 4.r,
                  ),
                ],
              ),
            )
          : FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    itemCount:
                        _galleryImages.isEmpty ? 1 : _galleryImages.length,
                    onPageChanged: (index) {
                      widget.onImageChanged?.call(index);
                    },
                    itemBuilder: (context, index) {
                      final imageUrl =
                          _galleryImages.isEmpty ? null : _galleryImages[index];
                      return Container(
                        color: const Color(0xFFF2F2F2),
                        child: imageUrl == null
                            ? Center(
                                child: PhosphorIcon(
                                  PhosphorIcons.image,
                                  size: 42.sp,
                                  color: const Color(0xFFBBBBBB),
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: _decodeDimension(context),
                                memCacheHeight: _decodeDimension(context),
                                fadeInDuration: Duration.zero,
                                filterQuality: FilterQuality.high,
                                placeholder: (context, url) => const ColoredBox(
                                  color: Color(0xFFF2F2F2),
                                  child: SizedBox.expand(),
                                ),
                                errorWidget: (context, url, error) => Center(
                                  child: PhosphorIcon(
                                    PhosphorIcons.imageBroken,
                                    size: 36.sp,
                                    color: const Color(0xFFBBBBBB),
                                  ),
                                ),
                              ),
                      );
                    },
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(12.w, 10.h, 16.w, 0),
                        child: Row(
                          children: <Widget>[
                            _CircleActionButton(
                              icon: PhosphorIcons.caretLeftBold,
                              onTap: widget.onBack,
                            ),
                            SizedBox(width: 8.w),
                            Image.asset(
                              'assets/icon/brand_logo.png',
                              height: 26.h,
                              cacheHeight: 104,
                              fit: BoxFit.contain,
                            ),
                            SizedBox(width: 6.w),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  'Bakaloo',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1A1414),
                                    height: 1.05,
                                  ),
                                ),
                                Text(
                                  'FRESHER EVERYDAY',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 7.5.sp,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.6,
                                    color: const Color(0xFF999999),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16.w,
                    right: 16.w,
                    bottom: 18.h,
                    child: Row(
                      children: <Widget>[
                        _FreshnessPill(),
                        if ((widget.highlights ?? const <String, dynamic>{})
                            .isNotEmpty) ...<Widget>[
                          SizedBox(width: 8.w),
                          _CircleActionButton(
                            icon: PhosphorIcons.sparkle,
                            onTap: _toggleHighlights,
                            dark: true,
                          ),
                        ],
                        const Spacer(),
                        _CircleActionButton(
                          icon: PhosphorIcons.shareNetworkBold,
                          onTap: widget.onShare,
                        ),
                        SizedBox(width: 8.w),
                        _CircleActionButton(
                          icon: widget.isWishlisted
                              ? PhosphorIcons.heartFill
                              : PhosphorIcons.heart,
                          iconColor:
                              widget.isWishlisted ? AppColors.brandRed : null,
                          onTap: widget.onWishlistToggle,
                        ),
                      ],
                    ),
                  ),
                  ProductHighlightsOverlay(
                    highlights: widget.highlights ?? const <String, dynamic>{},
                    isVisible: _showHighlights,
                    onClose: _toggleHighlights,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCollapsedBar() {
    final thumbnail = _thumbnailImage;

    return Container(
      height: 56.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      alignment: Alignment.center,
      child: Row(
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onBack,
            child: SizedBox(
              width: 36.w,
              height: 36.w,
              child: Center(
                child: PhosphorIcon(
                  PhosphorIcons.caretLeftBold,
                  size: 20.sp,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
          if (thumbnail != null) ...<Widget>[
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: thumbnail,
                width: 32.w,
                height: 32.w,
                fit: BoxFit.cover,
                memCacheWidth: 96,
                memCacheHeight: 96,
                fadeInDuration: Duration.zero,
                placeholder: (context, url) => Container(
                  width: 32.w,
                  height: 32.w,
                  color: const Color(0xFFF2F2F2),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 32.w,
                  height: 32.w,
                  color: const Color(0xFFF2F2F2),
                  child: Center(
                    child: PhosphorIcon(
                      PhosphorIcons.image,
                      size: 14.sp,
                      color: const Color(0xFFBBBBBB),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A1A),
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 2.h),
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: '₹${_displayPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A1A),
                          height: 1.2,
                        ),
                      ),
                      if (_isOnSale) ...<InlineSpan>[
                        WidgetSpan(child: SizedBox(width: 6.w)),
                        TextSpan(
                          text: '₹${widget.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF999999),
                            decoration: TextDecoration.lineThrough,
                            decorationColor: const Color(0xFF999999),
                            height: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onSearch,
            child: SizedBox(
              width: 28.w,
              height: 28.w,
              child: Center(
                child: PhosphorIcon(
                  PhosphorIcons.magnifyingGlassBold,
                  size: 18.sp,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onShare,
            child: SizedBox(
              width: 28.w,
              height: 28.w,
              child: Center(
                child: PhosphorIcon(
                  PhosphorIcons.shareNetworkBold,
                  size: 18.sp,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    this.onTap,
    this.iconColor,
    this.dark = false,
  });

  final PhosphorIconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: dark
              ? const Color(0xFF1A1A1A).withValues(alpha: 0.82)
              : Colors.white,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0x14000000),
              blurRadius: 8.r,
              offset: Offset(0, 2.h),
            ),
          ],
        ),
        child: Center(
          child: PhosphorIcon(
            icon,
            size: 20.sp,
            color: iconColor ?? (dark ? Colors.white : const Color(0xFF1A1A1A)),
          ),
        ),
      ),
    );
  }
}

class _FreshnessPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(100.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0x14000000),
            blurRadius: 8.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PhosphorIcon(
            PhosphorIcons.leafBold,
            size: 14.sp,
            color: const Color(0xFF0C831F),
          ),
          SizedBox(width: 5.w),
          Text(
            '100% Fresh',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1414),
            ),
          ),
        ],
      ),
    );
  }
}

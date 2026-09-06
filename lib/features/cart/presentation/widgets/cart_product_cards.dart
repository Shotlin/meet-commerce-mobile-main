import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CartProductCardGreen extends StatelessWidget {
  const CartProductCardGreen({
    required this.name,
    required this.price,
    super.key,
    this.salePrice,
    this.imageUrl,
    this.onAddTap,
    this.onHeartTap,
  });

  final String name;
  final double price;
  final double? salePrice;
  final String? imageUrl;
  final VoidCallback? onAddTap;
  final VoidCallback? onHeartTap;

  @override
  Widget build(BuildContext context) {
    final currentPrice = _effectivePrice(price, salePrice);
    final discount = _discountAmount(price, salePrice);

    return Container(
      width: 140.w,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
            child: SizedBox(
              height: 138.h,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _CardImage(
                    imageUrl: imageUrl,
                    width: 140.w,
                    memCacheWidth: 280,
                    memCacheHeight: 240,
                  ),
                  Positioned(
                    top: 10.h,
                    left: 10.w,
                    child: const _VegIndicator(),
                  ),
                  Positioned(
                    top: 10.h,
                    right: 10.w,
                    child: GestureDetector(
                      onTap: onHeartTap,
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 20.sp,
                        color: const Color(0xFFE23372),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10.w,
                    bottom: 12.h,
                    child: _PriceBadge(price: currentPrice),
                  ),
                  Positioned(
                    right: 10.w,
                    bottom: 10.h,
                    child: Material(
                      color: const Color(0xFF0AC26B),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: onAddTap,
                        customBorder: const CircleBorder(),
                        child: SizedBox(
                          width: 28.w,
                          height: 28.w,
                          child: Icon(
                            Icons.add_rounded,
                            size: 17.sp,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF222222),
                    height: 1.3,
                    fontFamily: 'Inter',
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: <Widget>[
                    if (discount > 0) ...<Widget>[
                      Text(
                        '₹${price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF9A9A9A),
                          decoration: TextDecoration.lineThrough,
                          decorationColor: const Color(0xFF9A9A9A),
                          fontFamily: 'Inter',
                        ),
                      ),
                      SizedBox(width: 6.w),
                    ],
                    Text(
                      '₹${currentPrice.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF222222),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
                if (discount > 0) ...<Widget>[
                  SizedBox(height: 8.h),
                  Row(
                    children: <Widget>[
                      Text(
                        '₹${discount.toStringAsFixed(0)} OFF',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF198038),
                          fontFamily: 'Inter',
                        ),
                      ),
                      SizedBox(width: 8.w),
                      const Expanded(child: _DashedLine()),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CartProductCardRed extends StatelessWidget {
  const CartProductCardRed({
    required this.name,
    required this.price,
    super.key,
    this.salePrice,
    this.imageUrl,
    this.onAddTap,
    this.onHeartTap,
  });

  final String name;
  final double price;
  final double? salePrice;
  final String? imageUrl;
  final VoidCallback? onAddTap;
  final VoidCallback? onHeartTap;

  @override
  Widget build(BuildContext context) {
    final currentPrice = _effectivePrice(price, salePrice);
    final discount = _discountAmount(price, salePrice);

    return Container(
      width: 120.w,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFF0E3E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
            child: SizedBox(
              height: 122.h,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _CardImage(
                    imageUrl: imageUrl,
                    width: 120.w,
                    memCacheWidth: 280,
                    memCacheHeight: 240,
                  ),
                  Positioned(
                    top: 10.h,
                    left: 10.w,
                    child: const _VegIndicator(),
                  ),
                  Positioned(
                    top: 10.h,
                    right: 10.w,
                    child: GestureDetector(
                      onTap: onHeartTap,
                      child: Icon(
                        Icons.favorite_border_rounded,
                        size: 20.sp,
                        color: const Color(0xFFE23372),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10.w,
                    bottom: 10.h,
                    child: _PriceBadge(price: currentPrice),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF222222),
                    height: 1.3,
                    fontFamily: 'Inter',
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: <Widget>[
                    if (discount > 0) ...<Widget>[
                      Text(
                        '₹${price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF9A9A9A),
                          decoration: TextDecoration.lineThrough,
                          decorationColor: const Color(0xFF9A9A9A),
                          fontFamily: 'Inter',
                        ),
                      ),
                      SizedBox(width: 6.w),
                    ],
                    Text(
                      '₹${currentPrice.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF222222),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
                if (discount > 0) ...<Widget>[
                  SizedBox(height: 7.h),
                  Row(
                    children: <Widget>[
                      Text(
                        '₹${discount.toStringAsFixed(0)} OFF',
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF198038),
                          fontFamily: 'Inter',
                        ),
                      ),
                      SizedBox(width: 6.w),
                      const Expanded(child: _DashedLine()),
                    ],
                  ),
                ],
                SizedBox(height: 10.h),
                SizedBox(
                  width: double.infinity,
                  height: 34.h,
                  child: OutlinedButton(
                    onPressed: onAddTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE23372),
                      side: const BorderSide(color: Color(0xFFE23372)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      'ADD',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFE23372),
                        fontFamily: 'Inter',
                      ),
                    ),
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

class _CardImage extends StatelessWidget {
  const _CardImage({
    required this.imageUrl,
    required this.width,
    required this.memCacheWidth,
    required this.memCacheHeight,
  });

  final String? imageUrl;
  final double width;
  final int memCacheWidth;
  final int memCacheHeight;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _CardImageFallback(width: width);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, __) => _CardImagePlaceholder(width: width),
      errorWidget: (_, __, ___) => _CardImageFallback(width: width),
    );
  }
}

class _CardImagePlaceholder extends StatelessWidget {
  const _CardImagePlaceholder({
    required this.width,
  });

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: const Color(0xFFF5F5F5),
      alignment: Alignment.center,
      child: SizedBox(
        width: 22.w,
        height: 22.w,
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFFE0E0E0),
        ),
      ),
    );
  }
}

class _CardImageFallback extends StatelessWidget {
  const _CardImageFallback({
    required this.width,
  });

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: const Color(0xFFF5F5F5),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        size: 26.sp,
        color: const Color(0xFFBDBDBD),
      ),
    );
  }
}

class _VegIndicator extends StatelessWidget {
  const _VegIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14.w,
      height: 14.w,
      padding: EdgeInsets.all(2.w),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF198038)),
        borderRadius: BorderRadius.circular(3.r),
        color: Colors.white,
      ),
      child: const DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFF198038),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _PriceBadge extends StatelessWidget {
  const _PriceBadge({
    required this.price,
  });

  final double price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: const Color(0xFF198038),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Colors.black,
            blurRadius: 0,
            offset: Offset(2, 2),
          ),
        ],
      ),
      child: Text(
        '₹${price.toStringAsFixed(0)}',
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashPainter(),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 6.0;
    const dashGap = 4.0;
    final paint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    double startX = 0;
    while (startX < size.width) {
      final endX = (startX + dashWidth).clamp(0.0, size.width).toDouble();
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(endX, size.height / 2),
        paint,
      );
      startX += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

double _effectivePrice(double price, double? salePrice) {
  if (salePrice != null && salePrice > 0 && salePrice < price) {
    return salePrice;
  }
  return price;
}

double _discountAmount(double price, double? salePrice) {
  if (salePrice == null || salePrice >= price) {
    return 0;
  }
  return price - salePrice;
}

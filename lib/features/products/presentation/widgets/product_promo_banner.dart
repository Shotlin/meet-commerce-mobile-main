import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Full-width brand-red delivery-promise strip shown right below the image
/// gallery. Deliberately just the one "Delivered in minutes with FreshCuts"
/// line + the real brand mark watermark — no extra icon/heading beyond
/// that, per direct product feedback on an earlier build of this banner.
class ProductPromoBanner extends StatelessWidget {
  const ProductPromoBanner({
    required this.scrollOffset,
    super.key,
  });

  final double scrollOffset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56.h,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Color(0xFFA81C1F),
            Color(0xFFD02428),
            Color(0xFFE5484B),
          ],
        ),
      ),
      child: ClipRect(
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // Faint brand watermark bleeding off the right edge.
            Positioned(
              right: -14.w,
              top: -10.h,
              bottom: -10.h,
              child: Transform.translate(
                offset: Offset(scrollOffset * 0.12, 0),
                child: Opacity(
                  opacity: 0.16,
                  child: Image.asset(
                    'assets/icon/brand_watermark.png',
                    height: 68.h,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  PhosphorIcon(
                    PhosphorIcons.scooterFill,
                    size: 32.sp,
                    color: Colors.white,
                  ),
                  SizedBox(width: 10.w),
                  RichText(
                    text: TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: 'Delivered in minutes with ',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.92),
                            height: 1.2,
                          ),
                        ),
                        TextSpan(
                          text: 'FreshCuts',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFFFD54F),
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
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

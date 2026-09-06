import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/shared/widgets/address_bottom_sheet.dart';

/// Pink delivery-ETA strip. Uses the product's own configured delivery
/// time when the admin has set one; otherwise a generic "fresh, fast"
/// line — never a fabricated specific time slot.
class ProductDeliveryBanner extends StatelessWidget {
  const ProductDeliveryBanner({required this.product, super.key});

  final ProductEntity product;

  @override
  Widget build(BuildContext context) {
    final subtitle = product.hasDeliveryTime
        ? 'Delivered in ${product.formattedDeliveryTime}'
        : 'Delivered fresh, fast';

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: const Color(0xFFFBEEEE),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          children: <Widget>[
            PhosphorIcon(
              PhosphorIcons.truckBold,
              size: 20.sp,
              color: const Color(0xFFD02428),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Get it delivered fresh',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1414),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => showAddressSheet(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Change',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFD02428),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16.sp,
                    color: const Color(0xFFD02428),
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

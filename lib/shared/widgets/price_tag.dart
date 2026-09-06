import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';

class PriceTag extends StatelessWidget {
  const PriceTag({
    required this.price,
    this.salePrice,
    this.mainStyle,
    this.mrpStyle,
    this.compact = false,
    super.key,
  });

  final double price;
  final double? salePrice;
  final TextStyle? mainStyle;
  final TextStyle? mrpStyle;
  final bool compact;

  bool get _isOnSale =>
      salePrice != null && salePrice! > 0 && salePrice! < price;

  int? get _discountPercent {
    if (!_isOnSale || price <= 0) {
      return null;
    }
    return (((price - salePrice!) / price) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final effectivePrice = _isOnSale ? salePrice! : price;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: compact ? 6.w : 8.w,
      runSpacing: 6.h,
      children: <Widget>[
        Text(
          effectivePrice.toInrCurrency,
          style: mainStyle ??
              AppTextStyles.labelLarge.copyWith(
                fontSize: compact ? 15.sp : 18.sp,
                fontWeight: FontWeight.w700,
              ),
        ),
        if (_isOnSale)
          Text(
            price.toInrCurrency,
            style: mrpStyle ??
                AppTextStyles.bodySmall.copyWith(
                  decoration: TextDecoration.lineThrough,
                ),
          ),
        if (_discountPercent != null)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8.w : 10.w,
              vertical: 4.h,
            ),
            decoration: BoxDecoration(
              color: AppColors.accentYellowLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            ),
            child: Text(
              '${_discountPercent!}% OFF',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.accentYellowDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

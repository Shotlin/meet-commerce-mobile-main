import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_item_entity.dart';

/// A single cart-item row: image, name/pack on the left, price + stepper
/// stacked on the right. Price is shown exactly once (the real unit price,
/// struck-through MRP + discounted price — never a computed line total),
/// and there is no per-item delivery-time line: that belongs to the
/// delivery box this row sits inside (see cart_delivery_groups.dart).
class CartItemCard extends StatelessWidget {
  const CartItemCard({
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
    this.disableIncrease = false,
    super.key,
  });

  final CartItemEntity item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;
  // Purchase-limits: greys out (and visually suppresses ripple on) the "+"
  // stepper when this line is at its limit. onIncrease stays wired
  // regardless — the actual block-and-toast happens in cart_screen.dart's
  // _updateItemQuantity, this only controls the affordance.
  final bool disableIncrease;

  @override
  Widget build(BuildContext context) {
    final hasDiscount = item.salePrice != null &&
        item.salePrice! > 0 &&
        item.salePrice! < item.price;
    final effectivePrice = item.effectivePrice;
    final outOfStock = !item.hasEnoughStock;

    return Slidable(
      key: ValueKey<String>(item.productId),
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.24,
        children: <Widget>[
          SlidableAction(
            onPressed: (_) => onRemove(),
            backgroundColor: AppColors.errorRed,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
          ),
        ],
      ),
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(14.w, 11.h, 14.w, 11.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Opacity(
              opacity: outOfStock ? 0.45 : 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9.r),
                child: SizedBox(
                  width: 72.w,
                  height: 72.w,
                  child:
                      item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: item.thumbnailUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 128,
                              memCacheHeight: 128,
                              fadeInDuration: const Duration(milliseconds: 150),
                              errorWidget: (context, url, error) => Container(
                                color: const Color(0xFFF4F4F4),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.shopping_basket_outlined,
                                  size: 22.sp,
                                  color: const Color(0xFFCCCCCC),
                                ),
                              ),
                            )
                          : Container(
                              color: const Color(0xFFF4F4F4),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.shopping_basket_outlined,
                                size: 22.sp,
                                color: const Color(0xFFCCCCCC),
                              ),
                            ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF222222),
                      height: 1.3,
                      fontFamily: 'Inter',
                    ),
                  ),
                  if (outOfStock)
                    Padding(
                      padding: EdgeInsets.only(top: 5.h),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDECEC),
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(color: const Color(0xFFF5B5B5)),
                        ),
                        child: Text(
                          item.stockQuantity <= 0
                              ? 'Out of stock'
                              : 'Only ${item.stockQuantity} left — reduce quantity',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFD32F2F),
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                  if (item.optionLabel != null && item.optionLabel!.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 3.h),
                      child: Text(
                        item.optionLabel!,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF888888),
                          fontFamily: 'Inter',
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: EdgeInsets.only(top: 3.h),
                      child: Text(
                        item.netQuantity ?? item.unit ?? '1 unit',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF888888),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Opacity(
                  opacity: outOfStock ? 0.5 : 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (hasDiscount) ...<Widget>[
                        Text(
                          '₹${item.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF999999),
                            decoration: TextDecoration.lineThrough,
                            decorationColor: const Color(0xFF999999),
                            fontFamily: 'Inter',
                          ),
                        ),
                        SizedBox(width: 6.w),
                      ],
                      Text(
                        outOfStock
                            ? 'Not included'
                            : '₹${effectivePrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A1A),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                _CartStepper(
                  quantity: item.quantity,
                  onDecrease: onDecrease,
                  onIncrease: onIncrease,
                  disableIncrease: disableIncrease,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Box-shaped stepper  ─ [–] count [+]  ─────────────────────────────────
// A single flat, bordered rectangle — no filled circular buttons. Minus
// and plus are just colored glyphs on the same box, matching the
// reference's plain outlined-box control rather than a pill of two
// separately-colored round buttons.

class _CartStepper extends StatelessWidget {
  const _CartStepper({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
    this.disableIncrease = false,
  });

  static const Color _borderColor = Color(0xFFF0C6C7);

  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final bool disableIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: _borderColor, width: 1.3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _StepButton(
            label: '−',
            onPressed: onDecrease,
          ),
          Container(width: 1, height: 18.h, color: _borderColor),
          SizedBox(
            width: 30.w,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A),
                fontFamily: 'Inter',
                height: 1,
              ),
            ),
          ),
          Container(width: 1, height: 18.h, color: _borderColor),
          _StepButton(
            label: '+',
            onPressed: onIncrease,
            disabled: disableIncrease,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.label,
    required this.onPressed,
    this.disabled = false,
  });

  static const Color _brandRed = Color(0xFFD02428);

  final String label;
  final VoidCallback onPressed;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : onPressed,
      child: Opacity(
        opacity: disabled ? 0.35 : 1,
        child: SizedBox(
          width: 32.w,
          height: 34.h,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: _brandRed,
                fontFamily: 'Inter',
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

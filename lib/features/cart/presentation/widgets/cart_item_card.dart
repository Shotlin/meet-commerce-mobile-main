import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_item_entity.dart';

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
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Opacity(
              opacity: outOfStock ? 0.45 : 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: SizedBox(
                  width: 64.w,
                  height: 64.w,
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
                      padding: EdgeInsets.only(top: 2.h),
                      child: Text(
                        item.optionLabel!,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF666666),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  if (item.optionLabel == null || item.optionLabel!.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 4.h),
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
                  // Delivery time badge
                  if (item.displayDeliveryMinutes != null &&
                      item.displayDeliveryMinutes! > 0)
                    Padding(
                      padding: EdgeInsets.only(top: 5.h),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.access_time_rounded,
                            size: 11.sp,
                            color: const Color(0xFF0AC26B),
                          ),
                          SizedBox(width: 3.w),
                          Text(
                            '${item.displayDeliveryMinutes} mins delivery',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF0AC26B),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 10.h),
                  Opacity(
                    opacity: outOfStock ? 0.5 : 1,
                    child: Row(
                      children: <Widget>[
                        if (hasDiscount) ...<Widget>[
                          Text(
                            '₹${item.price.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF999999),
                              decoration: TextDecoration.lineThrough,
                              decorationColor: const Color(0xFF999999),
                              fontFamily: 'Inter',
                            ),
                          ),
                          SizedBox(width: 8.w),
                        ],
                        Text(
                          '₹${effectivePrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0AC26B),
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                _CartStepper(
                  quantity: item.quantity,
                  onDecrease: onDecrease,
                  onIncrease: onIncrease,
                  disableIncrease: disableIncrease,
                ),
                SizedBox(height: 12.h),
                Opacity(
                  opacity: outOfStock ? 0.5 : 1,
                  child: Text(
                    '₹${item.total.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF222222),
                      fontFamily: 'Inter',
                      decoration: outOfStock
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                ),
                if (outOfStock)
                  Padding(
                    padding: EdgeInsets.only(top: 2.h),
                    child: Text(
                      'Not included',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF999999),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pill-shaped stepper  ─ [–] count [+]  ────────────────────────────────────
// – button: light violet surface + violet icon
// + button: solid violet fill + white icon
// Both buttons share the same pill container with a count in the middle.

class _CartStepper extends StatelessWidget {
  const _CartStepper({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
    this.disableIncrease = false,
  });

  static const Color _brandRedSurface = Color(0xFFFBEAEA);

  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final bool disableIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40.h,
      decoration: BoxDecoration(
        color: _brandRedSurface,
        borderRadius: BorderRadius.circular(50.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // ── minus ─────────────────────────────────────────────────────────
          _StepButton(
            icon: Icons.remove_rounded,
            onPressed: onDecrease,
            isFilled: false,
          ),
          // ── count ─────────────────────────────────────────────────────────
          SizedBox(
            width: 28.w,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A),
                fontFamily: 'Inter',
                height: 1,
              ),
            ),
          ),
          // ── plus ──────────────────────────────────────────────────────────
          _StepButton(
            icon: Icons.add_rounded,
            onPressed: onIncrease,
            isFilled: true,
            disabled: disableIncrease,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatefulWidget {
  const _StepButton({
    required this.icon,
    required this.onPressed,
    required this.isFilled,
    this.disabled = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isFilled; // true = solid violet (+), false = ghost (–)
  // Purely visual — onPressed always stays wired so a stale cache can
  // still be caught (and toasted) at the call site instead of the tap
  // silently doing nothing.
  final bool disabled;

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  double _scale = 1;

  static const Color _brandRed = Color(0xFFD02428);
  static const Color _brandRedSurface = Color(0xFFFBEAEA);

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTapDown:
            widget.disabled ? null : (_) => setState(() => _scale = 0.88),
        onTapUp: (_) {
          setState(() => _scale = 1);
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _scale = 1),
        child: Opacity(
          opacity: widget.disabled ? 0.4 : 1,
          child: Container(
            width: 40.h,
            height: 40.h,
            decoration: BoxDecoration(
              color: widget.isFilled ? _brandRed : _brandRedSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.icon,
              size: 18.sp,
              color: widget.isFilled ? Colors.white : _brandRed,
            ),
          ),
        ),
      ),
    );
  }
}

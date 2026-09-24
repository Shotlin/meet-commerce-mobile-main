import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_details/order_detail_palette.dart';
import 'package:bakaloo_flutter_app/shared/widgets/safe_product_image.dart';

/// Item 7 — the order's line items, with a "Download Invoice" link in the
/// header. Each [OrderItemTile] shows the strikethrough MRP + "X% OFF"
/// badge whenever the backend actually captured one at checkout time
/// (`orders.service.js#placeOrder` snapshots the cart line's real
/// `originalPrice`/`discountPercent` onto the order — not re-derived from
/// today's live price, which could have since changed) — an order placed
/// before that field existed, or one that genuinely had no discount, has
/// neither, and shows no badge rather than a fabricated one.
class OrderItemsCard extends StatelessWidget {
  const OrderItemsCard({
    required this.items,
    required this.onDownloadInvoice,
    required this.isDownloadingInvoice,
    required this.canDownloadInvoice,
    super.key,
  });

  final List<OrderItemEntity> items;
  final VoidCallback onDownloadInvoice;
  final bool isDownloadingInvoice;
  final bool canDownloadInvoice;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: OrderDetailPalette.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: OrderDetailPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Order Items (${items.length})',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w700,
                    color: OrderDetailPalette.textPrimary,
                  ),
                ),
              ),
              if (canDownloadInvoice)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isDownloadingInvoice ? null : onDownloadInvoice,
                    borderRadius: BorderRadius.circular(8.r),
                    child: Container(
                      constraints: BoxConstraints(minHeight: 44.h),
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (isDownloadingInvoice)
                            SizedBox(
                              width: 14.w,
                              height: 14.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  OrderDetailPalette.primaryRed,
                                ),
                              ),
                            )
                          else
                            Icon(
                              PhosphorIcons.downloadSimple,
                              size: 16.sp,
                              color: OrderDetailPalette.primaryRed,
                            ),
                          Gap(6.w),
                          Text(
                            'Download Invoice',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: OrderDetailPalette.primaryRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Gap(4.h),
          const Divider(color: OrderDetailPalette.headerDivider, height: 20),
          ...items.map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: OrderItemTile(item: item),
            ),
          ),
        ],
      ),
    );
  }
}

class OrderItemTile extends StatelessWidget {
  const OrderItemTile({required this.item, super.key});

  final OrderItemEntity item;

  bool get _hasDiscount =>
      item.discountPercent > 0 &&
      item.originalPrice != null &&
      item.originalPrice! > item.price;

  @override
  Widget build(BuildContext context) {
    final String subtitle = item.brand != null && item.brand!.trim().isNotEmpty
        ? '${item.unit} | ${item.brand}'
        : item.unit;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SafeProductImage(
          url: item.thumbnailUrl,
          size: 52.w,
          borderRadius: BorderRadius.circular(10.r),
          backgroundColor: OrderDetailPalette.surfaceMuted,
          iconSize: 20.sp,
        ),
        Gap(10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w600,
                  color: OrderDetailPalette.textPrimary,
                  height: 1.3,
                ),
              ),
              Gap(3.h),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.sp,
                  color: OrderDetailPalette.textSecondary,
                ),
              ),
              Gap(6.h),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6.w,
                runSpacing: 4.h,
                children: <Widget>[
                  Text(
                    item.price.toInrCurrency,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: OrderDetailPalette.textPrimary,
                    ),
                  ),
                  if (_hasDiscount) ...<Widget>[
                    Text(
                      item.originalPrice!.toInrCurrency,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.sp,
                        color: OrderDetailPalette.textSecondary,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: OrderDetailPalette.textSecondary,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: OrderDetailPalette.successGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        '${item.discountPercent}% OFF',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w700,
                          color: OrderDetailPalette.successGreen,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Gap(10.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              'Qty: ${item.quantity}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5.sp,
                color: OrderDetailPalette.textSecondary,
              ),
            ),
            Gap(3.h),
            Text(
              item.total.toInrCurrency,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w700,
                color: OrderDetailPalette.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

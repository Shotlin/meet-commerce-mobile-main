import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_details/order_detail_palette.dart';
import 'package:bakaloo_flutter_app/shared/widgets/safe_product_image.dart';

/// Item 7 — the order's line items, with a "Download Invoice" link in the
/// header. Each [OrderItemTile] shows only fields the backend actually
/// persists per line (`orders.repository.js#createCheckoutOrder`: name,
/// unit, quantity, price, total — no per-item MRP/discount is stored on a
/// placed order, only on the live cart before checkout), so there is no
/// strikethrough "was ₹X" price or discount badge here — showing one would
/// mean inventing a number that isn't real.
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
                InkWell(
                  onTap: isDownloadingInvoice ? null : onDownloadInvoice,
                  borderRadius: BorderRadius.circular(8.r),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 4.h,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (isDownloadingInvoice)
                          SizedBox(
                            width: 13.w,
                            height: 13.w,
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
                            size: 14.sp,
                            color: OrderDetailPalette.primaryRed,
                          ),
                        Gap(4.w),
                        Text(
                          'Download Invoice',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: OrderDetailPalette.primaryRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          Gap(4.h),
          const Divider(color: OrderDetailPalette.border, height: 20),
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

  @override
  Widget build(BuildContext context) {
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
                item.unit,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.sp,
                  color: OrderDetailPalette.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Gap(10.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              item.total.toInrCurrency,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w700,
                color: OrderDetailPalette.textPrimary,
              ),
            ),
            Gap(3.h),
            Text(
              'Qty: ${item.quantity}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5.sp,
                color: OrderDetailPalette.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

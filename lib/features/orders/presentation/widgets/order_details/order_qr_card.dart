import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_details/order_detail_palette.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';

/// The QR data this order encodes — its order number and id, in a plain,
/// self-describing format. There is no backend-issued per-order QR payload
/// (and no per-item batch/traceability QR — `OrderItemEntity` carries no
/// lot/batch id), so this is generated on-device from fields the order
/// already has. The exact same format is drawn onto the printed invoice
/// PDF (`invoiceGenerator.js#buildOrderQrPayload`) — scanning either one
/// resolves to the same order's vendor quality video via
/// `OrderQrScanScreen`/`GET /orders/:id/quality-videos`.
String orderQrPayload(OrderEntity order) =>
    'FRESHCUTS-ORDER|${order.orderNumber}|${order.id}';

/// Item 3 — "Scan / View QR" card. Tapping it opens the camera scanner
/// directly (no static popup any more — scanning either the printed
/// invoice's QR or this on-screen code resolves the vendor's cleaning/
/// packing video for this order's items). Download Invoice has its own
/// dedicated action on `OrderItemsCard`'s header, so this card no longer
/// duplicates it.
class OrderQrCard extends StatelessWidget {
  const OrderQrCard({
    required this.order,
    super.key,
  });

  final OrderEntity order;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OrderDetailPalette.white,
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        // Passes `order` as `extra` so the scanner can validate the
        // scanned QR belongs to THIS exact order — see `app_router.dart`'s
        // scanOrderQr route and `OrderQrScanScreen`'s `expectedOrderId`.
        onTap: () => context.push(RouteNames.scanOrderQr, extra: order),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: OrderDetailPalette.border),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 56.w,
                height: 56.w,
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: OrderDetailPalette.surfaceMuted,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: QrImageView(
                  data: orderQrPayload(order),
                  version: QrVersions.auto,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: OrderDetailPalette.textPrimary,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: OrderDetailPalette.textPrimary,
                  ),
                ),
              ),
              Gap(12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Scan to see how it was packed',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w700,
                        color: OrderDetailPalette.textPrimary,
                      ),
                    ),
                    Gap(3.h),
                    Text(
                      "Scan this code or your invoice's QR to watch the vendor's cleaning & packing video",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: OrderDetailPalette.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Gap(6.w),
              Icon(
                PhosphorIcons.caretRight,
                size: 18.sp,
                color: OrderDetailPalette.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

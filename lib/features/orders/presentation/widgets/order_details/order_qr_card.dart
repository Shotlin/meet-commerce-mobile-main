import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_details/order_detail_palette.dart';

/// The QR data this order encodes — its order number and id, in a plain,
/// self-describing format. There is no backend-issued per-order QR payload
/// (and no per-item batch/traceability QR — `OrderItemEntity` carries no
/// lot/batch id), so this is generated on-device from fields the order
/// already has, meant to be read back by a human (support desk, delivery
/// partner) rather than resolved by a URL: scanning it does not open a
/// link, it surfaces the exact order identity for quick verification.
String orderQrPayload(OrderEntity order) =>
    'FRESHCUTS-ORDER|${order.orderNumber}|${order.id}';

/// Item 3 — "Scan / View QR" card. Tapping it opens [showOrderQrSheet] for
/// a full-size code plus the real "Download Invoice" action (item 7's
/// action, surfaced here too since a QR/invoice pairing is what a customer
/// reaches for in the same moment).
class OrderQrCard extends StatelessWidget {
  const OrderQrCard({
    required this.order,
    required this.onDownloadInvoice,
    required this.isDownloadingInvoice,
    required this.canDownloadInvoice,
    super.key,
  });

  final OrderEntity order;
  final VoidCallback onDownloadInvoice;
  final bool isDownloadingInvoice;
  final bool canDownloadInvoice;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OrderDetailPalette.white,
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: () => showOrderQrSheet(
          context,
          order: order,
          onDownloadInvoice: onDownloadInvoice,
          isDownloadingInvoice: isDownloadingInvoice,
          canDownloadInvoice: canDownloadInvoice,
        ),
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
                      'Scan / View QR',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w700,
                        color: OrderDetailPalette.textPrimary,
                      ),
                    ),
                    Gap(3.h),
                    Text(
                      'Tap to view a larger code and your invoice',
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

Future<void> showOrderQrSheet(
  BuildContext context, {
  required OrderEntity order,
  required VoidCallback onDownloadInvoice,
  required bool isDownloadingInvoice,
  required bool canDownloadInvoice,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: OrderDetailPalette.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.fromLTRB(24.w, 4.h, 24.w, 28.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Order QR',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: OrderDetailPalette.textPrimary,
              ),
            ),
            Gap(16.h),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: OrderDetailPalette.surfaceMuted,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: QrImageView(
                data: orderQrPayload(order),
                version: QrVersions.auto,
                size: 200.w,
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
            Gap(14.h),
            Text(
              order.orderNumber,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: OrderDetailPalette.textPrimary,
              ),
            ),
            Gap(4.h),
            Text(
              'Show this to support or your delivery partner for quick order verification.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5.sp,
                color: OrderDetailPalette.textSecondary,
                height: 1.4,
              ),
            ),
            if (canDownloadInvoice) ...<Widget>[
              Gap(18.h),
              SizedBox(
                width: double.infinity,
                height: 46.h,
                child: OutlinedButton.icon(
                  onPressed: isDownloadingInvoice
                      ? null
                      : () {
                          Navigator.of(sheetContext).pop();
                          onDownloadInvoice();
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OrderDetailPalette.primaryRed,
                    side: const BorderSide(
                      color: OrderDetailPalette.primaryRed,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  icon: isDownloadingInvoice
                      ? SizedBox(
                          width: 16.w,
                          height: 16.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : PhosphorIcon(PhosphorIcons.filePdf, size: 16.sp),
                  label: const Text('Download Invoice'),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

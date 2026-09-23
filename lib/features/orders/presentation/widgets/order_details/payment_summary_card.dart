import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_details/order_detail_palette.dart';

String _prettyMethod(String value) {
  if (value.trim().isEmpty) return '—';
  return value.trim().toLowerCase().split('_').map((part) {
    if (part.isEmpty) return '';
    return '${part[0].toUpperCase()}${part.substring(1)}';
  }).join(' ');
}

(IconData, String) _methodIconAndLabel(String paymentMethod) {
  final normalized = paymentMethod.trim().toUpperCase();
  return switch (normalized) {
    'COD' => (PhosphorIcons.money, 'Cash on Delivery'),
    'WALLET' => (PhosphorIcons.wallet, 'FreshCuts Wallet'),
    'ONLINE' || 'RAZORPAY' || 'UPI' => (
        PhosphorIcons.deviceMobile,
        'Paid Online',
      ),
    _ => (PhosphorIcons.creditCard, _prettyMethod(paymentMethod)),
  };
}

/// Item 8 — payment method (+ transaction id when there is one) on the
/// left, the real bill breakdown on the right. Every figure here is a
/// field the checkout transaction actually wrote onto the order
/// (`orders.service.js#placeOrder`) — subtotal/discount/fees/tax/wallet/
/// total — nothing is recomputed or estimated client-side.
class PaymentSummaryCard extends StatelessWidget {
  const PaymentSummaryCard({required this.order, super.key});

  final OrderEntity order;

  @override
  Widget build(BuildContext context) {
    final (icon, methodLabel) = _methodIconAndLabel(order.paymentMethod);
    final balanceDue = order.total - order.walletAmountUsed;

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
          Text(
            'Payment Summary',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.5.sp,
              fontWeight: FontWeight.w700,
              color: OrderDetailPalette.textPrimary,
            ),
          ),
          Gap(14.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 34.w,
                      height: 34.w,
                      decoration: BoxDecoration(
                        color: OrderDetailPalette.surfaceMuted,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(
                        icon,
                        size: 17.sp,
                        color: OrderDetailPalette.primaryRed,
                      ),
                    ),
                    Gap(8.h),
                    Text(
                      methodLabel,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: OrderDetailPalette.textPrimary,
                      ),
                    ),
                    Gap(2.h),
                    Text(
                      _prettyMethod(order.paymentStatus),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5.sp,
                        color: OrderDetailPalette.textSecondary,
                      ),
                    ),
                    if (order.razorpayPaymentId != null) ...<Widget>[
                      Gap(6.h),
                      Text(
                        'Txn ID',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5.sp,
                          color: OrderDetailPalette.textSecondary,
                        ),
                      ),
                      Text(
                        order.razorpayPaymentId!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: OrderDetailPalette.textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Gap(16.w),
              Expanded(
                flex: 6,
                child: Column(
                  children: <Widget>[
                    _SummaryRow(label: 'Item Total', value: order.subtotal),
                    if (order.discount > 0)
                      _SummaryRow(
                        label: order.couponCode == null
                            ? 'Discount'
                            : 'Coupon (${order.couponCode})',
                        value: order.discount,
                        prefix: '-',
                        valueColor: OrderDetailPalette.successGreen,
                      ),
                    _SummaryRow(
                      label: 'Delivery Fee',
                      value: order.deliveryFee,
                      isFree: order.deliveryFee == 0,
                    ),
                    _SummaryRow(
                      label: 'Platform Fee',
                      value: order.platformFee,
                      isFree: order.platformFee == 0,
                    ),
                    if (order.taxAmount > 0)
                      _SummaryRow(label: 'Tax', value: order.taxAmount),
                    if (order.walletAmountUsed > 0)
                      _SummaryRow(
                        label: 'Wallet Used',
                        value: order.walletAmountUsed,
                        prefix: '-',
                        valueColor: OrderDetailPalette.successGreen,
                      ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: const Divider(
                        height: 1,
                        color: OrderDetailPalette.border,
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            order.walletAmountUsed > 0
                                ? 'Balance Due'
                                : 'Total Paid',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w700,
                              color: OrderDetailPalette.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          (order.walletAmountUsed > 0
                                  ? balanceDue
                                  : order.total)
                              .toInrCurrency,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: OrderDetailPalette.primaryRed,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.prefix = '',
    this.valueColor,
    this.isFree = false,
  });

  final String label;
  final double value;
  final String prefix;
  final Color? valueColor;
  final bool isFree;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 7.h),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5.sp,
                color: OrderDetailPalette.textSecondary,
              ),
            ),
          ),
          Text(
            isFree ? 'FREE' : '$prefix${value.toInrCurrency}',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
              color: isFree
                  ? OrderDetailPalette.successGreen
                  : (valueColor ?? OrderDetailPalette.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

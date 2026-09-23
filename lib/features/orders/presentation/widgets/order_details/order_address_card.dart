import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_timeline_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_details/order_detail_palette.dart';

/// Item 6 — delivery address plus Live Tracking / View on Map. Live
/// Tracking only shows once a rider can plausibly be attached to the order
/// (PACKED / OUT_FOR_DELIVERY — the same condition the rest of the app
/// already gates the tracking screen behind), matching real rider-assign
/// timing rather than offering a tracking link that would just 404/empty.
class OrderAddressCard extends StatelessWidget {
  const OrderAddressCard({required this.order, super.key});

  final OrderEntity order;

  bool get _isTrackable =>
      order.status == OrderStatus.PACKED ||
      order.status == OrderStatus.OUT_FOR_DELIVERY;

  @override
  Widget build(BuildContext context) {
    final address = order.deliveryAddress;
    final label = _readString(address, <String>['label'], fallback: 'Address');
    final name = _readString(address, <String>['name']);
    final phone = _readString(address, <String>['phone']);
    final line1 =
        _readString(address, <String>['addressLine1', 'address_line1']);
    final line2 =
        _readString(address, <String>['addressLine2', 'address_line2']);
    final landmark = _readString(address, <String>['landmark']);
    final city = _readString(address, <String>['city']);
    final state = _readString(address, <String>['state']);
    final pincode = _readString(address, <String>['pincode']);
    final lat = _readDouble(address, <String>['lat', 'latitude']);
    final lng = _readDouble(address, <String>['lng', 'longitude']);
    final hasCoordinates = lat != null && lng != null;

    final fullAddress = <String>[
      line1,
      if (line2.isNotEmpty) line2,
      if (landmark.isNotEmpty) landmark,
      <String>[city, state, pincode].where((item) => item.isNotEmpty).join(', '),
    ].where((item) => item.isNotEmpty).join(', ');

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                PhosphorIcons.mapPinFill,
                size: 20.sp,
                color: OrderDetailPalette.primaryRed,
              ),
              Gap(10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Delivery Address',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w700,
                        color: OrderDetailPalette.textPrimary,
                      ),
                    ),
                    Gap(6.h),
                    Text(
                      '$label${name.isNotEmpty ? ' • $name' : ''}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: OrderDetailPalette.textPrimary,
                      ),
                    ),
                    if (phone.isNotEmpty) ...<Widget>[
                      Gap(2.h),
                      Text(
                        phone,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.5.sp,
                          color: OrderDetailPalette.textSecondary,
                        ),
                      ),
                    ],
                    Gap(4.h),
                    Text(
                      fullAddress,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                        color: OrderDetailPalette.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (order.deliveryOtp != null &&
              order.deliveryOtp!.trim().isNotEmpty) ...<Widget>[
            Gap(14.h),
            _DeliveryOtpBanner(otp: order.deliveryOtp!.trim()),
          ],
          Gap(14.h),
          Row(
            children: <Widget>[
              if (_isTrackable) ...<Widget>[
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 40.h,
                    child: FilledButton.icon(
                      onPressed: () =>
                          context.push('/orders/${order.id}/track'),
                      style: FilledButton.styleFrom(
                        backgroundColor: OrderDetailPalette.ctaRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      icon: Icon(PhosphorIcons.navigationArrow, size: 16.sp),
                      label: Text(
                        'Live Tracking',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                Gap(8.w),
              ],
              Expanded(
                flex: _isTrackable ? 2 : 5,
                child: SizedBox(
                  height: 40.h,
                  child: OutlinedButton.icon(
                    onPressed: hasCoordinates
                        ? () => _openMap(lat, lng)
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OrderDetailPalette.textPrimary,
                      side: BorderSide(
                        color: hasCoordinates
                            ? OrderDetailPalette.border
                            : OrderDetailPalette.border.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    icon: Icon(PhosphorIcons.mapTrifold, size: 16.sp),
                    label: Text(
                      'View on Map',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _readString(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return fallback;
  }

  double? _readDouble(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
}

class _DeliveryOtpBanner extends StatelessWidget {
  const _DeliveryOtpBanner({required this.otp});

  final String otp;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: OrderDetailPalette.primaryRedSurface,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            PhosphorIcons.shieldCheck,
            size: 18.sp,
            color: OrderDetailPalette.primaryRed,
          ),
          Gap(8.w),
          Expanded(
            child: Text(
              'Delivery OTP — share only with your delivery partner',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5.sp,
                color: OrderDetailPalette.textSecondary,
                height: 1.3,
              ),
            ),
          ),
          Gap(8.w),
          Text(
            otp,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: OrderDetailPalette.primaryRed,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';

class CartAddressHeader extends StatefulWidget {
  const CartAddressHeader({
    required this.address,
    required this.onTap,
    super.key,
  });

  final AddressEntity address;
  final VoidCallback onTap;

  @override
  State<CartAddressHeader> createState() => _CartAddressHeaderState();
}

class _CartAddressHeaderState extends State<CartAddressHeader> {
  String _distanceLabel = 'Near you';

  @override
  void initState() {
    super.initState();
    _hydrateDistance();
  }

  @override
  void didUpdateWidget(covariant CartAddressHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address.id != widget.address.id) {
      _hydrateDistance();
    }
  }

  Future<void> _hydrateDistance() async {
    final distanceLabel = await _resolveDistanceLabel();
    if (!mounted || distanceLabel == null) {
      return;
    }
    setState(() {
      _distanceLabel = distanceLabel;
    });
  }

  Future<String?> _resolveDistanceLabel() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition();
      final meters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        widget.address.latitude,
        widget.address.longitude,
      );

      if (meters < 1000) {
        return '${meters.round()} m';
      }

      final km = meters / 1000;
      if (km > 50) {
        return null;
      }
      final digits = km >= 10 ? 0 : 1;
      return '${km.toStringAsFixed(digits)} km';
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final label =
        widget.address.label.trim().isEmpty ? 'Other' : widget.address.label;
    final addressLine = <String>[
      widget.address.addressLine1,
      if ((widget.address.addressLine2 ?? '').trim().isNotEmpty)
        widget.address.addressLine2!.trim(),
      widget.address.city,
    ].join(', ');

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: 85.h),
          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFF0F0F0)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF222222),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18.sp,
                          color: const Color(0xFF222222),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      addressLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8C00),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      _distanceLabel,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

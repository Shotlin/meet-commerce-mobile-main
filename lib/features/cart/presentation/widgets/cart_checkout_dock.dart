import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';

/// Cart's sticky bottom dock — a compact address row plus a single primary
/// CTA. Deliberately carries no payment-method UI of its own: tapping the
/// CTA (once an address is set) hands off to `CheckoutScreen`
/// (`RouteNames.checkout`), which owns wallet/online/COD selection. This
/// replaces the old `CartBottomBar`, which used to place the order directly
/// from the cart screen with two payment buttons + a wallet stripe inline.
class CartCheckoutDock extends StatelessWidget {
  const CartCheckoutDock({
    required this.hasAddress,
    required this.toPay,
    super.key,
    this.selectedAddress,
    this.isLocationNotServiceable = false,
    this.onAddAddress,
    this.onEditAddress,
    this.onContinue,
  });

  final bool hasAddress;
  final AddressEntity? selectedAddress;
  final double toPay;

  /// True when the customer's last auto-detected location landed outside
  /// every shop's service area — see `non_serviceable_location_provider.dart`.
  /// Ignored whenever `hasAddress` is true.
  final bool isLocationNotServiceable;

  final VoidCallback? onAddAddress;
  final VoidCallback? onEditAddress;

  /// Pushes `CheckoutScreen`. Only reachable once `hasAddress` is true.
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFEFEFEF))),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (hasAddress && selectedAddress != null) ...<Widget>[
              _AddressRow(address: selectedAddress!, onTap: onEditAddress),
              SizedBox(height: 8.h),
            ] else if (isLocationNotServiceable) ...<Widget>[
              const _NotServiceableRow(),
              SizedBox(height: 8.h),
            ],
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                onPressed: hasAddress ? onContinue : onAddAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandRed,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  hasAddress
                      ? 'Pay ${_formatInr(toPay)}'
                      : 'Add Address to Proceed',
                  style: TextStyle(
                    fontSize: 15.5.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatInr(double v) => '₹${v.toStringAsFixed(0)}';
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address, this.onTap});

  final AddressEntity address;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = address.label.trim().isEmpty ? 'Address' : address.label;
    final preview = <String>[
      address.addressLine1,
      if ((address.addressLine2 ?? '').trim().isNotEmpty)
        address.addressLine2!.trim(),
      address.city,
    ].join(', ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: Row(
            children: <Widget>[
              Icon(Icons.home_rounded, size: 15.sp, color: const Color(0xFF666666)),
              SizedBox(width: 7.w),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: '$label, ',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF222222),
                          fontFamily: 'Inter',
                        ),
                      ),
                      TextSpan(
                        text: preview,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF888888),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 6.w),
              Icon(Icons.edit_outlined, size: 14.sp, color: const Color(0xFF999999)),
            ],
          ),
        ),
      ),
    );
  }
}

/// No CTA of its own on purpose — no address was ever saved for this
/// location, and "Add Address" would just fail the same serviceability
/// check again. Matches the informational-only intent of the old
/// `CartBottomBar._buildNotServiceableState`.
class _NotServiceableRow extends StatelessWidget {
  const _NotServiceableRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(Icons.info_outline_rounded, size: 15.sp, color: AppColors.brandRed),
        SizedBox(width: 7.w),
        Expanded(
          child: Text(
            "Your area isn't serviceable yet. We'll be there soon!",
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF555555),
              fontFamily: 'Inter',
            ),
          ),
        ),
      ],
    );
  }
}

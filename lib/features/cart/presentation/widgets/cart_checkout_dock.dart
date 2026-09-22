import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';

/// Cart's sticky bottom dock — a compact address row plus two premium,
/// equal-width payment buttons (Cash on Delivery / Pay Online). Placing an
/// order happens directly from the cart — there is no separate Checkout
/// page in this flow any more; both buttons already reflect the real
/// payable amount after coupon + wallet.
class CartCheckoutDock extends StatelessWidget {
  const CartCheckoutDock({
    required this.hasAddress,
    required this.toPay,
    super.key,
    this.selectedAddress,
    this.isLocationNotServiceable = false,
    this.onAddAddress,
    this.onEditAddress,
    this.onPlaceCod,
    this.onPlaceOnline,
    this.isPlacing = false,
    this.codAvailable = true,
    this.codUnavailableReason,
    this.onlineAvailable = true,
  });

  final bool hasAddress;
  final AddressEntity? selectedAddress;

  /// The real amount left to pay — after coupon discount and any wallet
  /// balance applied — shown on both buttons.
  final double toPay;

  /// True when the customer's last auto-detected location landed outside
  /// every shop's service area — see `non_serviceable_location_provider.dart`.
  /// Ignored whenever `hasAddress` is true.
  final bool isLocationNotServiceable;

  final VoidCallback? onAddAddress;
  final VoidCallback? onEditAddress;

  /// Places the order directly (COD / Pay Online). Only reachable once
  /// `hasAddress` is true; `null` while a placement is already in flight.
  final VoidCallback? onPlaceCod;
  final VoidCallback? onPlaceOnline;

  final bool isPlacing;
  final bool codAvailable;
  final String? codUnavailableReason;
  final bool onlineAvailable;

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
              SizedBox(height: 10.h),
            ] else if (isLocationNotServiceable) ...<Widget>[
              const _NotServiceableRow(),
              SizedBox(height: 10.h),
            ],
            if (!hasAddress)
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: onAddAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandRed,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'Add Address to Proceed',
                    style: TextStyle(
                      fontSize: 15.5.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              )
            else
              Row(
                children: <Widget>[
                  Expanded(
                    child: _DockButton(
                      label: 'Cash on Delivery',
                      amount: toPay,
                      isPrimary: false,
                      isLoading: isPlacing,
                      disabled: !codAvailable,
                      disabledReason: codUnavailableReason,
                      onPressed: (isPlacing || !codAvailable) ? null : onPlaceCod,
                    ),
                  ),
                  Gap(10.w),
                  Expanded(
                    child: _DockButton(
                      label: 'Pay Online',
                      amount: toPay,
                      isPrimary: true,
                      isLoading: isPlacing,
                      disabled: !onlineAvailable,
                      onPressed: (isPlacing || !onlineAvailable) ? null : onPlaceOnline,
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

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.label,
    required this.amount,
    required this.isPrimary,
    required this.isLoading,
    required this.disabled,
    required this.onPressed,
    this.disabledReason,
  });

  final String label;
  final double amount;
  final bool isPrimary;
  final bool isLoading;
  final bool disabled;
  final String? disabledReason;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? SizedBox(
            width: 18.w,
            height: 18.w,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                isPrimary ? Colors.white : AppColors.brandRed,
              ),
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w700,
                  color: isPrimary
                      ? Colors.white
                      : (disabled ? const Color(0xFFAAAAAA) : AppColors.brandRed),
                  fontFamily: 'Inter',
                ),
              ),
              Gap(1.h),
              Text(
                '₹${amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: isPrimary
                      ? Colors.white
                      : (disabled ? const Color(0xFFAAAAAA) : AppColors.brandRed),
                  fontFamily: 'Inter',
                ),
              ),
            ],
          );

    final button = SizedBox(
      width: double.infinity,
      height: 54.h,
      child: isPrimary
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandRed,
                disabledBackgroundColor: AppColors.brandRed.withValues(alpha: 0.4),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brandRed,
                side: BorderSide(
                  color: disabled
                      ? const Color(0xFFDDDDDD)
                      : AppColors.brandRed.withValues(alpha: 0.55),
                  width: 1.4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: child,
            ),
    );

    if (!disabled || disabledReason == null || disabledReason!.isEmpty) {
      return button;
    }

    return Tooltip(message: disabledReason!, child: button);
  }
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

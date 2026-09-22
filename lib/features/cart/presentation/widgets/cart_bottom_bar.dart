import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';

class CartBottomBar extends StatelessWidget {
  const CartBottomBar({
    required this.hasAddress,
    required this.toPay,
    super.key,
    this.hasCompleteAddress = true,
    this.isLocationNotServiceable = false,
    this.onAddAddress,
    this.onCompleteAddress,
    this.onPayOnline,
    this.onCod,
    this.isPlacingOrder = false,
    this.onlineEnabled = true,
    this.codEnabled = true,
    this.paymentMethodsKnown = true,
    this.showWalletToggle = false,
    this.walletBalance = 0,
    this.walletApplied = 0,
    this.orderTotal = 0,
    this.useWallet = false,
    this.onToggleWallet,
    this.onAddMoney,
    this.onPayFullWallet,
    this.selectedAddress,
    this.onEditAddress,
  });

  final bool hasAddress;
  final double toPay;
  final VoidCallback? onAddAddress;

  /// The address this order will ship to — shown as a compact "Home,
  /// {address}" strip above the payment buttons, same address
  /// `CartAddressHeader` (top of the scroll) lets the customer change.
  /// Null hides the strip (nothing selected yet).
  final AddressEntity? selectedAddress;
  final VoidCallback? onEditAddress;

  /// Whether the address `hasAddress` refers to has House No./Building
  /// filled in — customers can now get this far with an address that only
  /// ever came from reverse geocoding (see home_screen.dart's
  /// _maybeShowLocationPrompt, which no longer forces completion at app
  /// open). This is the one place that gap actually needs to block
  /// something — placing an order needs a full address, browsing doesn't.
  /// Ignored while `hasAddress` is false (that state takes priority).
  final bool hasCompleteAddress;

  /// True when the customer's last auto-detected location (via "Use my
  /// current location") landed outside every shop's service area — no
  /// address ever got saved for it (the backend hard-blocks that), so
  /// `hasAddress` is false too, but this is what tells the bar to show an
  /// informational "not serviceable" banner instead of the ordinary "Add
  /// Address to Proceed" CTA. See non_serviceable_location_provider.dart.
  /// Ignored whenever `hasAddress` is true.
  final bool isLocationNotServiceable;

  /// "Complete Your Address" CTA — shown instead of the payment buttons
  /// when `hasAddress` is true but `hasCompleteAddress` is false.
  final VoidCallback? onCompleteAddress;
  final VoidCallback? onPayOnline;
  final VoidCallback? onCod;
  final bool isPlacingOrder;

  /// False only while there has never yet been a successful payment-methods
  /// answer for this cart (first load, or a hard failure with nothing
  /// cached). The two `*Enabled` flags default to `true` so a caller that
  /// genuinely doesn't track this keeps the old always-enabled behavior —
  /// but while this is false, those flags must be treated as an unverified
  /// guess and the bar shows a loading placeholder instead of buttons a
  /// customer could act on.
  final bool paymentMethodsKnown;

  /// Admin toggles (Settings → Payments on the dashboard) — each button
  /// reflects these directly: disabled (visible, greyed, not tappable)
  /// when its method is off. When both are off, the whole row is replaced
  /// by an "unavailable" message instead of two dead buttons.
  final bool onlineEnabled;
  final bool codEnabled;

  /// Wallet balance is an orthogonal toggle here — never a separate
  /// exclusive payment method — offsetting `toPay` against whichever of
  /// Pay Online / Cash on Delivery the customer ends up tapping. Shown
  /// only when there's a genuine balance to offer (see
  /// CartScreen.build()'s `canUseWallet`).
  final bool showWalletToggle;
  final double walletBalance;
  final double walletApplied;
  /// The order's real payable total, before any wallet offset — used only
  /// to decide whether the wallet stripe's expanded action is "Pay via
  /// Wallet" (balance covers this in full) or "Add Money" (it doesn't).
  /// `toPay` above is the post-wallet remainder shown to the customer;
  /// this is the pre-wallet figure the sufficiency check needs.
  final double orderTotal;
  final bool useWallet;
  final ValueChanged<bool>? onToggleWallet;
  final VoidCallback? onAddMoney;
  final VoidCallback? onPayFullWallet;

  bool get _readyForPayment => hasAddress && hasCompleteAddress;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          border: const Border(
            top: BorderSide(color: Color(0xFFF0F0F0)),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: _readyForPayment ? 0.08 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (selectedAddress != null) ...<Widget>[
              _MiniAddressStrip(
                address: selectedAddress!,
                onTap: onEditAddress,
              ),
              SizedBox(height: 10.h),
            ],
            _readyForPayment
                ? _buildPaymentState()
                : (hasAddress
                    ? _buildPinkCta(
                        label: 'Complete Your Address',
                        onPressed: onCompleteAddress,
                      )
                    : (isLocationNotServiceable
                        ? _buildNotServiceableState()
                        : _buildPinkCta(
                            label: 'Add Address to Proceed',
                            onPressed: onAddAddress,
                          ))),
          ],
        ),
      ),
    );
  }

  /// No CTA at all here on purpose — there's nothing for the customer to
  /// tap that would help (no address got saved for this location, and
  /// Add Address would just fail the same serviceability check again).
  /// They can still try a different address from Home's own location
  /// picker; this bar only reports the state, it doesn't offer a way out.
  Widget _buildNotServiceableState() {
    return _buildInfoBanner(
      "Your area isn't serviceable yet. We'll be there soon!",
    );
  }

  Widget _buildPinkCta({required String label, required VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE23372),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentState() {
    if (!paymentMethodsKnown) {
      return _buildPaymentButtonsLoadingState();
    }
    if (!onlineEnabled && !codEnabled) {
      return _buildUnavailableState();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showWalletToggle) ...<Widget>[
          _WalletToggleStripe(
            walletBalance: walletBalance,
            walletApplied: walletApplied,
            orderTotal: orderTotal,
            value: useWallet,
            enabled: !isPlacingOrder,
            onChanged: onToggleWallet ?? (_) {},
            onAddMoney: onAddMoney,
            onPayFullWallet: onPayFullWallet,
          ),
          SizedBox(height: 10.h),
        ],
        Row(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(right: 10.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'To Pay',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF666666),
                      fontFamily: 'Inter',
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '₹${toPay.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF222222),
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SizedBox(
                height: 52.h,
                child: OutlinedButton.icon(
                  onPressed:
                      (onlineEnabled && !isPlacingOrder) ? onPayOnline : null,
                  icon: Icon(Icons.credit_card_rounded, size: 18.sp),
                  label: Text(
                    'Pay Online',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD02428),
                    disabledForegroundColor:
                        const Color(0xFFD02428).withValues(alpha: 0.4),
                    side: BorderSide(
                      color: const Color(0xFFD02428)
                          .withValues(alpha: onlineEnabled ? 1 : 0.35),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: SizedBox(
                height: 52.h,
                child: ElevatedButton(
                  onPressed:
                      (codEnabled && !isPlacingOrder) ? onCod : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD02428),
                    disabledBackgroundColor:
                        const Color(0xFFD02428).withValues(alpha: 0.35),
                    foregroundColor: Colors.white,
                    disabledForegroundColor:
                        Colors.white.withValues(alpha: 0.8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: isPlacingOrder
                      ? SizedBox(
                          width: 18.w,
                          height: 18.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Cash on Delivery',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontFamily: 'Inter',
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Shown only until the real summary — payment methods AND price — is
  /// known for the first time. Both the price and the buttons shimmer
  /// together rather than showing a guessed ₹ figure next to a guessed
  /// button state: the two were never independent (both come from the same
  /// backend summary), so a customer must never see one update ahead of
  /// the other. Same 52.h row the real buttons occupy, so there's no
  /// layout jump when they swap in.
  Widget _buildPaymentButtonsLoadingState() {
    Widget block({double? width}) {
      return Container(
        width: width,
        height: 52.h,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(14.r),
        ),
      );
    }

    return Row(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(right: 10.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'To Pay',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF666666),
                  fontFamily: 'Inter',
                ),
              ),
              SizedBox(height: 4.h),
              Container(
                width: 64.w,
                height: 20.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F2),
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: block()),
        SizedBox(width: 10.w),
        Expanded(child: block()),
      ],
    );
  }

  Widget _buildUnavailableState() {
    return _buildInfoBanner(
      'Payment methods are currently unavailable. Please check back shortly.',
    );
  }

  Widget _buildInfoBanner(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5FB),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE3DCF2)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.info_outline_rounded,
            color: const Color(0xFFD02428),
            size: 20.sp,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF3A2E52),
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact "Home, {address preview}" strip pinned above the payment
/// buttons — the sticky-dock equivalent of the fuller `CartAddressHeader`
/// card at the top of the scroll. Tapping it opens the same address list.
class _MiniAddressStrip extends StatelessWidget {
  const _MiniAddressStrip({required this.address, this.onTap});

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
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.home_rounded,
                size: 16.sp,
                color: const Color(0xFF666666),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: '$label, ',
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF222222),
                          fontFamily: 'Inter',
                        ),
                      ),
                      TextSpan(
                        text: preview,
                        style: TextStyle(
                          fontSize: 12.5.sp,
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
              SizedBox(width: 8.w),
              Icon(
                Icons.edit_outlined,
                size: 15.sp,
                color: const Color(0xFF999999),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wallet card — a single compact, premium row, never a second row or
/// expanding panel. Offsets [CartBottomBar]'s "To Pay" figure against
/// whichever of Pay Online / Cash on Delivery the customer taps, rather
/// than being its own separate payment method. Shown only when the admin
/// allows wallet at all (even at zero balance — see CartScreen.build()'s
/// `showWalletStripe`).
///
/// Two mutually-exclusive right-hand states, chosen purely by whether the
/// balance covers the order — never by the switch, which doesn't exist in
/// the sufficient case at all:
/// - Balance ≥ order total: one primary "Pay with Wallet" button. No
///   switch, no Add Money — tapping it pays the whole order from the
///   wallet directly.
/// - Balance < order total: the ordinary switch (applies whatever balance
///   exists as a partial discount against Pay Online / Cash on Delivery in
///   the background) plus a compact "Add Money" button, pre-filled with
///   the shortfall.
class _WalletToggleStripe extends StatelessWidget {
  const _WalletToggleStripe({
    required this.walletBalance,
    required this.walletApplied,
    required this.orderTotal,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.onAddMoney,
    this.onPayFullWallet,
  });

  final double walletBalance;
  final double walletApplied;
  final double orderTotal;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onAddMoney;
  final VoidCallback? onPayFullWallet;

  static const _brandRed = Color(0xFFD02428);
  static const _redBg = Color(0xFFFBEAEA);
  static const _borderColor = Color(0xFFF0C6C7);
  static const _titleColor = Color(0xFF171717);
  static const _mutedGray = Color(0xFF737684);

  bool get _hasBalance => walletBalance > 0;
  bool get _sufficient => walletBalance >= orderTotal && orderTotal > 0;

  @override
  Widget build(BuildContext context) {
    final active = value && _hasBalance && !_sufficient;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Colors.white, Color(0xFFFAF8FF)],
        ),
        borderRadius: BorderRadius.circular(17.r),
        border: Border.all(color: _borderColor),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: _redBg,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              color: _brandRed,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'FreshCuts Wallet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: _titleColor,
                    fontFamily: 'Inter',
                  ),
                ),
                SizedBox(height: 3.h),
                Text.rich(
                  _sufficient
                      ? TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text:
                                  '₹${walletBalance.toStringAsFixed(0)} ',
                              style: const TextStyle(
                                color: _brandRed,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(text: 'available  |  '),
                            TextSpan(
                              text: '₹${orderTotal.toStringAsFixed(0)} ',
                              style: const TextStyle(
                                color: _brandRed,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(text: 'order total'),
                          ],
                        )
                      : active && walletApplied > 0
                          ? TextSpan(
                              children: <InlineSpan>[
                                TextSpan(
                                  text:
                                      '₹${walletApplied.toStringAsFixed(0)} ',
                                  style: const TextStyle(
                                    color: _brandRed,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const TextSpan(text: 'applied  |  '),
                                TextSpan(
                                  text:
                                      '₹${walletBalance.toStringAsFixed(0)} ',
                                  style: const TextStyle(
                                    color: _brandRed,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const TextSpan(text: 'available'),
                              ],
                            )
                          : TextSpan(
                              text: _hasBalance
                                  ? '₹${walletBalance.toStringAsFixed(0)} available'
                                  : 'No balance yet',
                            ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: _mutedGray,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          if (_sufficient)
            _PayWithWalletButton(
              onPressed: enabled ? onPayFullWallet : null,
            )
          else ...<Widget>[
            _AddMoneyButton(onPressed: enabled ? onAddMoney : null),
            SizedBox(width: 8.w),
            _CheckmarkToggle(
              value: value,
              enabled: enabled,
              onChanged: onChanged,
            ),
          ],
        ],
      ),
    );
  }
}

/// A compact checkbox-style toggle — a filled purple checkmark (on) or an
/// outlined circle (off) — used instead of a [Switch] specifically because
/// Switch's minimum track width (~34dp, ~90px on this density) was, next to
/// the "Add Money" button, squeezing the wallet card's title/subtitle text
/// column down to where "FreshCuts Wallet" wrapped onto two lines and the
/// whole card ballooned past its intended compact height. This toggle is
/// roughly a third of that width.
class _CheckmarkToggle extends StatelessWidget {
  const _CheckmarkToggle({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  static const _brandRed = Color(0xFFD02428);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: enabled ? () => onChanged(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 24.w,
        height: 24.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: value ? _brandRed : Colors.transparent,
          border: Border.all(
            color: value ? _brandRed : const Color(0xFFC7C7CC),
            width: 1.6,
          ),
        ),
        child: value
            ? Icon(Icons.check_rounded, color: Colors.white, size: 15.sp)
            : null,
      ),
    );
  }
}

/// The single, primary CTA shown instead of the switch/Add Money pair once
/// the wallet balance alone covers the order — a filled purple gradient
/// pill, the strongest visual weight in the row since it's a one-tap
/// commit, not a navigation.
class _PayWithWalletButton extends StatelessWidget {
  const _PayWithWalletButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(13.r),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(13.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: onPressed != null
                  ? const <Color>[Color(0xFFD02428), Color(0xFFA81C1F)]
                  : <Color>[
                      const Color(0xFFD02428).withValues(alpha: 0.4),
                      const Color(0xFFA81C1F).withValues(alpha: 0.4),
                    ],
            ),
            borderRadius: BorderRadius.circular(13.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 16.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                'Pay with Wallet',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The compact outlined "Add Money" button shown alongside the switch when
/// the balance doesn't yet cover the order — navigates to top-up,
/// pre-filled with the shortfall.
class _AddMoneyButton extends StatelessWidget {
  const _AddMoneyButton({required this.onPressed});

  final VoidCallback? onPressed;

  static const _brandRed = Color(0xFFD02428);

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _brandRed,
        backgroundColor: Colors.white,
        side: const BorderSide(color: _brandRed, width: 1.5),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13.r),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.add_rounded, size: 14.sp),
          SizedBox(width: 3.w),
          Text(
            'Add Money',
            style: TextStyle(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}

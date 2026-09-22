import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/features/cart/domain/entities/bill_summary_entity.dart';

/// Bill Summary — a flat, compact section (no card/shadow) rendering the
/// backend-calculated canonical breakdown. All amounts come from the
/// backend TotalsEngine; nothing is recomputed here. Delivery fee shows the
/// dynamic distance-based amount (or FREE when waived) with a real
/// free-delivery progress hint — never a fabricated membership offer.
/// Savings is a single compact expandable row here rather than a separate
/// standalone card; expanding it reveals the same itemized breakdown a
/// dedicated savings card used to show.
class CartBillSummary extends StatefulWidget {
  const CartBillSummary({required this.summary, super.key, this.walletApplied = 0});

  final BillSummaryEntity summary;

  /// Wallet balance applied against `summary.payable` — a pure display
  /// value, computed the same `min(balance, payable)` way everywhere
  /// (checkout_provider.dart#walletApplied) so this row can never disagree
  /// with the dock's own buttons or what the backend will actually charge.
  final double walletApplied;

  @override
  State<CartBillSummary> createState() => _CartBillSummaryState();
}

class _CartBillSummaryState extends State<CartBillSummary> {
  static const Color _ink = Color(0xFF1A1A1A);
  static const Color _muted = Color(0xFF888888);
  static const Color _green = Color(0xFF0AC26B);
  static const Color _neonRed = Color(0xFFFF1E1E);
  static const Color _divider = Color(0xFFF0F0F0);

  static const Map<String, ({Color color, String symbol})> _savingsIcons =
      <String, ({Color color, String symbol})>{
    'mrp_discount': (color: Color(0xFFF5A623), symbol: '%'),
    'handling_waiver': (color: Color(0xFFFF6B35), symbol: '₹'),
    'late_night_waiver': (color: _green, symbol: '✓'),
    'first_time_offer': (color: _green, symbol: '🎁'),
  };

  /// Fee codes already rendered via dedicated typed fields above — anything
  /// else in `summary.fees` (e.g. SURGE_FEE / rain fee, PACKAGING_FEE) is
  /// rendered generically so a new admin-configured fee type never silently
  /// disappears from the bill again.
  static const Set<String> _dedicatedFeeCodes = <String>{
    'DELIVERY_FEE',
    'HANDLING_FEE',
    'PLATFORM_FEE',
    'SMALL_CART_FEE',
  };

  bool _savingsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final delivery = summary.deliveryFee;
    final free = summary.freeDelivery;
    final distanceKnown =
        summary.distance.known && summary.distance.label.isNotEmpty;

    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Bill summary',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: _ink,
                fontFamily: 'Inter',
              ),
            ),
            Gap(14.h),

            // ── Item total ──────────────────────────────────────
            _BillRow(
              label: 'Item total',
              originalAmount: summary.itemTotal.original !=
                      summary.itemTotal.discounted
                  ? summary.itemTotal.original
                  : null,
              amount: summary.itemTotal.discounted,
            ),
            Gap(12.h),

            // ── Coupon / first-time-offer discount ──────────────
            // Both share one "discount slot" on the backend (a manually
            // applied coupon always takes priority over the auto-applied
            // first-time offer), so the same amount field covers either —
            // only the label/icon change based on which one is active.
            if (summary.couponDiscount > 0) ...<Widget>[
              _CouponDiscountRow(
                amount: summary.couponDiscount,
                label: summary.firstTimeOffer?.name ?? 'Coupon discount',
                icon: summary.firstTimeOffer != null
                    ? PhosphorIcons.giftFill
                    : PhosphorIcons.tagFill,
              ),
              Gap(12.h),
            ],

            // ── Cashback already earned on this order ───────────
            // Unlike the discount above, cashback doesn't reduce what's
            // payable now — it's a wallet credit after the order — so
            // it never touches the discount slot and both an unlocked
            // first-time-offer cashback and a cart-milestone cashback
            // can show at once if the customer happens to qualify for
            // both. Purely informational: only ever shown once the
            // reward is actually locked in, not as a "still trying to
            // unlock" progress hint.
            if ((summary.firstTimeOffer?.cashbackAmount ?? 0) > 0) ...<Widget>[
              _CashbackEarnedRow(
                amount: summary.firstTimeOffer!.cashbackAmount,
                label: summary.firstTimeOffer!.name,
              ),
              Gap(12.h),
            ],
            if (summary.cartMilestone.unlocked?.rewardType == 'CASHBACK' &&
                (summary.cartMilestone.unlocked?.cashbackAmount ?? 0) >
                    0) ...<Widget>[
              _CashbackEarnedRow(
                amount: summary.cartMilestone.unlocked!.cashbackAmount,
                label: summary.cartMilestone.unlocked!.name,
              ),
              Gap(12.h),
            ],

            // ── Delivery fee ────────────────────────────────────
            _BillRow(
              label: 'Delivery fee',
              amount: delivery.amount,
              originalAmount: delivery.isFree && delivery.originalAmount > 0
                  ? delivery.originalAmount
                  : null,
              isFree: delivery.isFree,
              onInfo: distanceKnown
                  ? () => _showInfoSheet(
                        context,
                        'Delivery fee',
                        delivery.isFree
                            ? 'Free delivery unlocked on this order.'
                            : 'Calculated by distance — ${summary.distance.label} from the store.',
                      )
                  : null,
            ),
            // Sub-text: distance + free-delivery hint. This is the only
            // "offer strip" the bill ever shows, and only when the real
            // free-delivery threshold data says there's something to
            // unlock — never a purchasable plan/membership card.
            if (delivery.isFree) ...<Widget>[
              Gap(6.h),
              _SubNote(
                icon: PhosphorIcons.sealCheckFill,
                text: free.threshold != null
                    ? 'Free delivery unlocked on orders above ₹${_fmt(free.threshold!)}'
                    : 'Free delivery unlocked',
                color: _green,
              ),
            ] else ...<Widget>[
              if (distanceKnown) ...<Widget>[
                Gap(6.h),
                _SubNote(
                  icon: PhosphorIcons.mapPin,
                  text: '${summary.distance.label} from store',
                  color: _muted,
                ),
              ],
              if (free.enabled && free.amountToUnlock > 0) ...<Widget>[
                Gap(6.h),
                _SubNote(
                  icon: PhosphorIcons.moped,
                  text:
                      'Add ₹${_fmt(free.amountToUnlock)} more for free delivery',
                  color: _green,
                ),
              ],
            ],

            // ── Free delivery progress bar ──────────────────────
            if (free.enabled &&
                !delivery.isFree &&
                free.threshold != null &&
                free.amountToUnlock > 0) ...<Widget>[
              Gap(8.h),
              _FreeDeliveryProgress(
                subtotal: summary.itemTotal.discounted,
                threshold: free.threshold!,
              ),
            ],
            Gap(12.h),

            // ── Handling fee ────────────────────────────────────
            // Label/description are admin-configurable (dashboard Settings
            // → Fees) and come straight from the backend — falls back to
            // this default copy only for a cached response predating
            // those fields, never hardcoded otherwise.
            if (summary.handlingFee.amount > 0) ...<Widget>[
              _BillRow(
                label: summary.handlingFee.label ?? 'Handling fee',
                amount: summary.handlingFee.amount,
                onInfo: () => _showInfoSheet(
                  context,
                  summary.handlingFee.label ?? 'Handling fee',
                  summary.handlingFee.description ??
                      'Covers packing, quality checks and order handling so your items arrive safely.',
                ),
              ),
              Gap(12.h),
            ],

            // ── Platform fee ────────────────────────────────────
            if (summary.platformFee.amount > 0) ...<Widget>[
              _BillRow(
                label: summary.platformFee.label ?? 'Platform fee',
                amount: summary.platformFee.amount,
                onInfo: () => _showInfoSheet(
                  context,
                  summary.platformFee.label ?? 'Platform fee',
                  summary.platformFee.description ??
                      'Helps us run the platform and provide customer support.',
                ),
              ),
              Gap(12.h),
            ],

            // ── Small cart fee ──────────────────────────────────
            // Reason shown inline below (not behind an info-icon tap)
            // so it's visible at a glance, unlike the other fee rows.
            if (summary.smallCartFee.amount > 0) ...<Widget>[
              _BillRow(
                label: summary.smallCartFee.label ?? 'Small cart fee',
                amount: summary.smallCartFee.amount,
              ),
              Gap(6.h),
              _SubNote(
                icon: PhosphorIcons.info,
                text: summary.smallCartFee.description ??
                    'Applied to smaller orders. Add a few more items to avoid this fee.',
                color: _neonRed,
              ),
              Gap(12.h),
            ],

            // ── Other dynamic fees (rain/surge, packaging, etc.) ─
            // These arrive only in the generic `fees` list — DELIVERY_FEE,
            // HANDLING_FEE, PLATFORM_FEE and SMALL_CART_FEE already have
            // dedicated rows above, so skip those codes here to avoid
            // double-counting.
            for (final FeeLine fee in summary.fees.where(
              (FeeLine f) => !_dedicatedFeeCodes.contains(f.code) &&
                  f.amount > 0 &&
                  !f.waived,
            )) ...<Widget>[
              _BillRow(
                label: fee.label.isNotEmpty ? fee.label : 'Fee',
                amount: fee.amount,
                onInfo: fee.description.isNotEmpty
                    ? () => _showInfoSheet(
                          context,
                          fee.label.isNotEmpty ? fee.label : 'Fee',
                          fee.description,
                        )
                    : null,
              ),
              Gap(12.h),
            ],

            // ── Tip ─────────────────────────────────────────────
            if (summary.tipAmount > 0) ...<Widget>[
              _BillRow(
                label: 'Delivery partner tip',
                amount: summary.tipAmount,
              ),
              Gap(12.h),
            ],

            // ── Savings — a compact expandable row, not a separate
            //    standalone card. Expanding reveals the same itemized
            //    breakdown a dedicated savings card used to show.
            if (summary.savings.total > 0) ...<Widget>[
              _SavingsRow(
                total: summary.savings.total,
                expanded: _savingsExpanded,
                onToggle: () =>
                    setState(() => _savingsExpanded = !_savingsExpanded),
              ),
              if (_savingsExpanded) ...<Widget>[
                Gap(10.h),
                ...List<Widget>.generate(summary.savings.items.length, (i) {
                  final item = summary.savings.items[i];
                  final config = _savingsIcons[item.type] ??
                      const (color: _green, symbol: '✓');
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom:
                          i == summary.savings.items.length - 1 ? 0 : 8.h,
                    ),
                    child: _SavingsItemRow(
                      color: config.color,
                      symbol: config.symbol,
                      label: item.label,
                      amount: item.amount,
                    ),
                  );
                }),
              ],
              Gap(12.h),
            ],

            // ── FreshCuts Wallet applied ─────────────────────────
            if (widget.walletApplied > 0) ...<Widget>[
              _WalletAppliedRow(amount: widget.walletApplied),
              Gap(12.h),
            ],

            Padding(
              padding: EdgeInsets.symmetric(vertical: 2.h),
              child: const Divider(height: 1, thickness: 1, color: _divider),
            ),
            Gap(12.h),

            // ── Amount to be paid ────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Amount to be paid',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    fontFamily: 'Inter',
                  ),
                ),
                Row(
                  children: <Widget>[
                    if (summary.toPay.original > summary.payable ||
                        widget.walletApplied > 0) ...<Widget>[
                      Text(
                        '₹${_fmt(widget.walletApplied > 0 ? summary.payable : summary.toPay.original)}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF999999),
                          decoration: TextDecoration.lineThrough,
                          decorationColor: const Color(0xFF999999),
                          fontFamily: 'Inter',
                        ),
                      ),
                      Gap(7.w),
                    ],
                    Text(
                      '₹${_fmt(_finalPayable)}',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double get _finalPayable {
    final value = widget.summary.payable - widget.walletApplied;
    return value < 0 ? 0 : value;
  }

  static String _fmt(double v) => v.toStringAsFixed(0);

  void _showInfoSheet(BuildContext context, String title, String body) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 28.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
            ),
            Gap(18.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: _ink,
                fontFamily: 'Inter',
              ),
            ),
            Gap(8.h),
            Text(
              body,
              style: TextStyle(
                fontSize: 14.sp,
                height: 1.5,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF555555),
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Row primitive
// ─────────────────────────────────────────────────────────────────────────────

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.label,
    required this.amount,
    this.originalAmount,
    this.isFree = false,
    this.onInfo,
  });

  final String label;
  final double amount;
  final double? originalAmount;
  final bool isFree;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF555555),
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              if (onInfo != null) ...<Widget>[
                Gap(4.w),
                GestureDetector(
                  onTap: onInfo,
                  behavior: HitTestBehavior.opaque,
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 14.sp,
                    color: const Color(0xFFAAAAAA),
                  ),
                ),
              ],
            ],
          ),
        ),
        Row(
          children: <Widget>[
            if (originalAmount != null) ...<Widget>[
              Text(
                '₹${originalAmount!.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF999999),
                  decoration: TextDecoration.lineThrough,
                  decorationColor: const Color(0xFF999999),
                  fontFamily: 'Inter',
                ),
              ),
              Gap(6.w),
            ],
            Text(
              isFree ? 'FREE' : '₹${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: isFree
                    ? const Color(0xFF0AC26B)
                    : const Color(0xFF222222),
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Savings — compact expandable row (replaces the old standalone card)
// ─────────────────────────────────────────────────────────────────────────────

class _SavingsRow extends StatelessWidget {
  const _SavingsRow({
    required this.total,
    required this.expanded,
    required this.onToggle,
  });

  final double total;
  final bool expanded;
  final VoidCallback onToggle;

  static const Color _green = Color(0xFF0AC26B);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Savings',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF555555),
                  fontFamily: 'Inter',
                ),
              ),
              Gap(4.w),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 17.sp,
                color: const Color(0xFFAAAAAA),
              ),
            ],
          ),
          Text(
            '-₹${total.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: _green,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}

class _SavingsItemRow extends StatelessWidget {
  const _SavingsItemRow({
    required this.color,
    required this.symbol,
    required this.label,
    required this.amount,
  });

  final Color color;
  final String symbol;
  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 22.w,
          height: 22.w,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          alignment: Alignment.center,
          child: Text(
            symbol,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
          ),
        ),
        Gap(10.w),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF666666),
              fontFamily: 'Inter',
            ),
          ),
        ),
        Gap(8.w),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF222222),
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-note (distance / free-delivery hint)
// ─────────────────────────────────────────────────────────────────────────────

class _SubNote extends StatelessWidget {
  const _SubNote({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        PhosphorIcon(icon, size: 13.sp, color: color),
        Gap(5.w),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: color,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Coupon discount row — green, shows amount saved with a tag icon
// ─────────────────────────────────────────────────────────────────────────────

class _CouponDiscountRow extends StatelessWidget {
  const _CouponDiscountRow({
    required this.amount,
    this.label = 'Coupon discount',
    this.icon = PhosphorIcons.tagFill,
  });

  final double amount;
  final String label;
  final IconData icon;

  static const Color _green = Color(0xFF0AC26B);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PhosphorIcon(
                icon,
                size: 14.sp,
                color: _green,
              ),
              Gap(6.w),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: _green,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
        ),
        Text(
          '−₹${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: _green,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FreshCuts Wallet applied — reduces "Amount to be paid" directly, unlike
// the cashback-earned row below which is only ever informational.
// ─────────────────────────────────────────────────────────────────────────────

class _WalletAppliedRow extends StatelessWidget {
  const _WalletAppliedRow({required this.amount});

  final double amount;

  static const Color _green = Color(0xFF0AC26B);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PhosphorIcon(
                PhosphorIcons.walletFill,
                size: 14.sp,
                color: _green,
              ),
              Gap(6.w),
              Flexible(
                child: Text(
                  'FreshCuts Wallet applied',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: _green,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
        ),
        Text(
          '−₹${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: _green,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cashback-earned row — green, confirms a wallet credit already locked in
// (unlike _CouponDiscountRow, this never subtracts from "Amount to be paid")
// ─────────────────────────────────────────────────────────────────────────────

class _CashbackEarnedRow extends StatelessWidget {
  const _CashbackEarnedRow({required this.amount, required this.label});

  final double amount;
  final String label;

  static const Color _green = Color(0xFF0AC26B);
  static const Color _greenBg = Color(0xFFEAFBF3);
  static const Color _greenBorder = Color(0xFFBEEED9);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: _greenBg,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: _greenBorder),
      ),
      child: Row(
        children: <Widget>[
          PhosphorIcon(
            PhosphorIcons.wallet,
            size: 18.sp,
            color: _green,
          ),
          Gap(10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '₹${amount.toStringAsFixed(0)} cashback on this order',
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w700,
                    color: _green,
                    fontFamily: 'Inter',
                  ),
                ),
                if (label.isNotEmpty) ...<Widget>[
                  Gap(2.h),
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w500,
                      color: _green.withValues(alpha: 0.8),
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Free-delivery progress bar
// ─────────────────────────────────────────────────────────────────────────────

class _FreeDeliveryProgress extends StatelessWidget {
  const _FreeDeliveryProgress({
    required this.subtotal,
    required this.threshold,
  });

  final double subtotal;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final progress =
        threshold <= 0 ? 1.0 : (subtotal / threshold).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999.r),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 6.h,
        backgroundColor: const Color(0xFFEFEFEF),
        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0AC26B)),
      ),
    );
  }
}

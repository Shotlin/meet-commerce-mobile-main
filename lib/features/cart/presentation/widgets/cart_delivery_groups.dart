import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/features/checkout/domain/entities/delivery_slot_entity.dart';

/// One delivery-group card: a header row (clock/calendar icon, timing
/// label, item-count sub-label, "Change Slot" CTA) followed by that
/// group's cart-item rows. Purely presentational — the caller supplies the
/// already-built item rows so this widget stays free of cart/business logic.
class CartDeliveryGroupCard extends StatelessWidget {
  const CartDeliveryGroupCard({
    required this.timingLabel,
    required this.itemRows,
    super.key,
    this.subLabel,
    this.isScheduled = false,
    this.isClosed = false,
    this.changeSlotLabel,
    this.onChangeSlot,
    this.onExpressTap,
    this.onViewHoursTap,
  });

  /// Factory that mirrors the previous single-slot `CartDeliveryHeader`'s
  /// label logic, so every call site (single-group or multi-group carts)
  /// renders identical copy for the ASAP/scheduled/closed-store states.
  factory CartDeliveryGroupCard.fromSlot({
    required int estimateMinutes,
    required List<Widget> itemRows,
    SelectedDeliverySlot? selectedSlot,
    String? nextAvailableLabel,
    VoidCallback? onScheduleTap,
    VoidCallback? onExpressTap,
    VoidCallback? onViewHoursTap,
  }) {
    final slot = selectedSlot ?? const SelectedDeliverySlot.asap();
    final isScheduled = slot.isScheduled;
    final isClosed = !isScheduled && nextAvailableLabel != null;

    return CartDeliveryGroupCard(
      timingLabel: isScheduled
          ? 'Scheduled delivery'
          : isClosed
              ? 'Store closed — next available'
              : 'Delivering in $estimateMinutes mins',
      // A second line only when it conveys something the timing label
      // itself doesn't already say (the actual scheduled time, or the
      // next window once the store's closed) — the plain "Delivering in
      // X mins" case is a single line, matching the reference exactly.
      subLabel: isScheduled
          ? slot.displayLabel(estimateMinutes).replaceFirst('Scheduled for ', '')
          : isClosed
              ? nextAvailableLabel
              : null,
      isScheduled: isScheduled,
      isClosed: isClosed,
      // Omitted (not just disabled) when the caller passes no handler — a
      // secondary, informational-only group (an item whose own delivery
      // estimate differs from the cart's real, actionable ASAP/Scheduled
      // slot) has nothing for "Change"/"Express" to actually do, since
      // this app only supports one delivery preference per cart.
      changeSlotLabel:
          onScheduleTap == null ? null : (isScheduled ? 'Change' : 'Schedule'),
      onChangeSlot: onScheduleTap,
      onExpressTap: isScheduled ? null : onExpressTap,
      onViewHoursTap: onViewHoursTap,
      itemRows: itemRows,
    );
  }

  final String timingLabel;
  final String? subLabel;
  final bool isScheduled;
  final bool isClosed;
  final String? changeSlotLabel;
  final VoidCallback? onChangeSlot;
  final VoidCallback? onExpressTap;
  final VoidCallback? onViewHoursTap;
  final List<Widget> itemRows;

  @override
  Widget build(BuildContext context) {
    final accent = isScheduled
        ? const Color(0xFFD02428)
        : isClosed
            ? const Color(0xFFB45309)
            : const Color(0xFF0AC26B);

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFEFEFEF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 11.h, 12.w, 11.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 30.w,
                      height: 30.w,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isScheduled || isClosed
                            ? Icons.calendar_month_outlined
                            : Icons.bolt_rounded,
                        size: 16.sp,
                        color: accent,
                      ),
                    ),
                    SizedBox(width: 9.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            timingLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1A1A),
                              fontFamily: 'Inter',
                            ),
                          ),
                          if (subLabel != null) ...<Widget>[
                            SizedBox(height: 1.h),
                            Text(
                              subLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF888888),
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (changeSlotLabel != null) ...<Widget>[
                      SizedBox(width: 8.w),
                      _ChipCta(
                        label: changeSlotLabel!,
                        icon: isScheduled
                            ? Icons.edit_calendar_outlined
                            : Icons.calendar_month_outlined,
                        color: accent,
                        background: accent.withValues(alpha: 0.08),
                        onTap: onChangeSlot,
                      ),
                    ],
                  ],
                ),
                if (onExpressTap != null || onViewHoursTap != null) ...<Widget>[
                  SizedBox(height: 10.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      if (onExpressTap != null)
                        _ChipCta(
                          label: 'Express',
                          icon: Icons.bolt_rounded,
                          color: const Color(0xFFEA580C),
                          background: const Color(0xFFFFF7ED),
                          onTap: onExpressTap,
                        ),
                      if (onViewHoursTap != null) ...<Widget>[
                        SizedBox(width: 8.w),
                        IconButton(
                          onPressed: onViewHoursTap,
                          icon: Icon(
                            Icons.schedule_rounded,
                            size: 18.sp,
                            color: const Color(0xFF999999),
                          ),
                          tooltip: 'Store hours',
                          constraints:
                              BoxConstraints(minWidth: 32.w, minHeight: 32.h),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF2F2F2)),
          ...itemRows,
        ],
      ),
    );
  }
}

class _ChipCta extends StatelessWidget {
  const _ChipCta({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 8.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 14.sp, color: color),
              SizedBox(width: 4.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w700,
                  color: color,
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

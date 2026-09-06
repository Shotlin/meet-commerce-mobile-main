import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/features/checkout/domain/entities/delivery_slot_entity.dart';

class CartDeliveryHeader extends StatelessWidget {
  const CartDeliveryHeader({
    required this.estimateMinutes,
    required this.itemCount,
    super.key,
    this.selectedSlot,
    this.onScheduleTap,
    this.onExpressTap,
    this.nextAvailableLabel,
    this.onViewHoursTap,
  });

  final int estimateMinutes;
  final int itemCount;
  final SelectedDeliverySlot? selectedSlot;
  final VoidCallback? onScheduleTap;
  /// Opens the schedule sheet straight into ASAP/quick-delivery mode —
  /// a dedicated shortcut so the customer doesn't have to open "Schedule"
  /// and then realize ASAP was the tab they wanted all along.
  final VoidCallback? onExpressTap;
  /// Set only when the store is closed and the customer is still on ASAP —
  /// replaces the "Delivering in X mins" line with the next real available
  /// window instead of continuing to promise an estimate that can't be met.
  final String? nextAvailableLabel;
  /// Opens the "view store hours" sheet. Only rendered when provided.
  final VoidCallback? onViewHoursTap;

  @override
  Widget build(BuildContext context) {
    final itemLabel = '$itemCount item${itemCount == 1 ? '' : 's'}';
    final slot = selectedSlot ?? const SelectedDeliverySlot.asap();
    final isScheduled = slot.isScheduled;
    final isClosed = !isScheduled && nextAvailableLabel != null;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                isScheduled || isClosed
                    ? Icons.calendar_month_outlined
                    : Icons.access_time_outlined,
                size: 28.sp,
                color: isScheduled
                    ? const Color(0xFFD02428)
                    : isClosed
                        ? const Color(0xFFB45309)
                        : const Color(0xFF666666),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (isScheduled)
                      Text(
                        'Scheduled delivery',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFD02428),
                          fontFamily: 'Inter',
                        ),
                      )
                    else if (isClosed)
                      Text(
                        'Store closed — next available',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFB45309),
                          fontFamily: 'Inter',
                        ),
                      )
                    else
                      RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF222222),
                            fontFamily: 'Inter',
                          ),
                          children: <InlineSpan>[
                            const TextSpan(text: 'Delivering in '),
                            TextSpan(
                              text: '$estimateMinutes mins',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF222222),
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 2.h),
                    Text(
                      isScheduled
                          ? slot.displayLabel(estimateMinutes).replaceFirst(
                              'Scheduled for ', '')
                          : isClosed
                              ? nextAvailableLabel!
                              : itemLabel,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: isScheduled || isClosed
                            ? FontWeight.w500
                            : FontWeight.w400,
                        color: isScheduled
                            ? const Color(0xFFD02428)
                            : isClosed
                                ? const Color(0xFFB45309)
                                : const Color(0xFF888888),
                        fontFamily: 'Inter',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onViewHoursTap != null)
                IconButton(
                  onPressed: onViewHoursTap,
                  icon: Icon(
                    Icons.schedule_rounded,
                    size: 20.sp,
                    color: const Color(0xFF888888),
                  ),
                  tooltip: 'Store hours',
                  constraints: BoxConstraints(minWidth: 36.w, minHeight: 36.h),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              if (onExpressTap != null) ...<Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onExpressTap,
                    icon: Icon(
                      Icons.bolt_rounded,
                      size: 16.sp,
                      color: const Color(0xFFEA580C),
                    ),
                    label: Text(
                      'Express',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFEA580C),
                        fontFamily: 'Inter',
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFF7ED),
                      foregroundColor: const Color(0xFFEA580C),
                      side: const BorderSide(
                        color: Color(0xFFFDBA74),
                        width: 1.5,
                      ),
                      minimumSize: Size(0, 38.h),
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onScheduleTap,
                  icon: Icon(
                    isScheduled
                        ? Icons.edit_calendar_outlined
                        : Icons.calendar_month_outlined,
                    size: 16.sp,
                    color: isScheduled
                        ? const Color(0xFFD02428)
                        : const Color(0xFF0AC26B),
                  ),
                  label: Text(
                    isScheduled ? 'Change' : 'Schedule',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: isScheduled
                          ? const Color(0xFFD02428)
                          : const Color(0xFF0AC26B),
                      fontFamily: 'Inter',
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: isScheduled
                        ? const Color(0xFFD02428)
                        : const Color(0xFF0AC26B),
                    side: BorderSide(
                      color: isScheduled
                          ? const Color(0xFFD02428)
                          : const Color(0xFF0AC26B),
                      width: 1.5,
                    ),
                    minimumSize: Size(0, 38.h),
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
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
}

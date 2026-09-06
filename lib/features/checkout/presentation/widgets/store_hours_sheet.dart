import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:bakaloo_flutter_app/features/checkout/domain/entities/store_status_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/store_status_provider.dart';

const _kGreen = Color(0xFF0AC26B);
const _kAmber = Color(0xFFB45309);
const _kAmberBg = Color(0xFFFEF3C7);
const _kBlack = Color(0xFF111827);
const _kGrey = Color(0xFF6B7280);
const _kGreyLight = Color(0xFFF3F4F6);
const _kWhite = Colors.white;

const _kWeekdayLabels = {
  'monday': 'Monday',
  'tuesday': 'Tuesday',
  'wednesday': 'Wednesday',
  'thursday': 'Thursday',
  'friday': 'Friday',
  'saturday': 'Saturday',
  'sunday': 'Sunday',
};

/// Bottom sheet showing the next 7 days' store open/closed status and
/// hours — the mobile surface for "view store hours", sourced from
/// [storeStatusProvider] (already fetched by the cart/checkout gating
/// logic, so opening this sheet triggers no new network call).
class StoreHoursSheet extends ConsumerWidget {
  const StoreHoursSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const StoreHoursSheet(),
    );
  }

  String _dayLabel(int index, String weekday) {
    if (index == 0) return 'Today';
    if (index == 1) return 'Tomorrow';
    return _kWeekdayLabels[weekday] ?? weekday;
  }

  String _formatTime(String? hhmm) {
    if (hhmm == null) return '';
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1];
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m $period';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(storeStatusProvider);
    final days = statusAsync.asData?.value.next7Days ?? const <StoreDayAvailability>[];

    return Container(
      constraints: BoxConstraints(maxHeight: 0.8.sh),
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 10.h, bottom: 4.h),
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(99.r),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 16.w, 12.h),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Store hours',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: _kBlack,
                          fontFamily: 'Inter',
                        ),
                      ),
                      Gap(2.h),
                      Text(
                        'When we\'re open for delivery',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: _kGrey,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: _kGrey, size: 22.sp),
                ),
              ],
            ),
          ),
          if (days.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
              child: Text(
                'Store hours aren\'t set up yet — the store is open for delivery.',
                style: TextStyle(fontSize: 13.sp, color: _kGrey, fontFamily: 'Inter'),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 20.h),
                itemCount: days.length,
                separatorBuilder: (_, __) => Gap(8.h),
                itemBuilder: (context, index) {
                  final day = days[index];
                  final hoursText = day.open != null && day.close != null
                      ? '${_formatTime(day.open)} – ${_formatTime(day.close)}'
                      : (day.reason ?? (day.isOpen ? 'Open all day' : 'Closed'));
                  return _DayRow(
                    label: _dayLabel(index, day.weekday),
                    isOpen: day.isOpen,
                    hoursText: hoursText,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.label,
    required this.isOpen,
    required this.hoursText,
  });

  final String label;
  final bool isOpen;
  final String hoursText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: _kGreyLight,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: _kBlack,
                fontFamily: 'Inter',
              ),
            ),
          ),
          Text(
            hoursText,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: isOpen ? _kGrey : _kAmber,
              fontFamily: 'Inter',
            ),
          ),
          Gap(8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: isOpen ? _kGreen.withValues(alpha: 0.12) : _kAmberBg,
              borderRadius: BorderRadius.circular(99.r),
            ),
            child: Text(
              isOpen ? 'Open' : 'Closed',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: isOpen ? _kGreen : _kAmber,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

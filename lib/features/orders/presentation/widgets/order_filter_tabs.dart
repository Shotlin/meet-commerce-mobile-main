import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_list_provider.dart';

/// One shared light-gray rounded track holding all four filters — the
/// selected one gets an inset filled brand-red pill, the rest are plain
/// text directly on the track (no individual pill background each).
/// `OrderFilter.failed` has no slot here (matches the reference, which
/// only shows All/Delivered/Processing/Cancelled) — it stays reachable as
/// a filter value elsewhere in the codebase, just not surfaced in this row.
class OrderFilterTabs extends StatelessWidget {
  const OrderFilterTabs({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final OrderFilter selected;
  final ValueChanged<OrderFilter> onSelected;

  static const List<OrderFilter> _visibleFilters = <OrderFilter>[
    OrderFilter.all,
    OrderFilter.delivered,
    OrderFilter.active,
    OrderFilter.cancelled,
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        height: 44.h,
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFF2),
          borderRadius: BorderRadius.circular(100.r),
        ),
        child: Row(
          children: _visibleFilters
              .map(
                (filter) => Expanded(
                  child: _FilterSegment(
                    label: _labelFor(filter),
                    selected: filter == selected,
                    onTap: () => onSelected(filter),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  String _labelFor(OrderFilter filter) {
    // "Processing" (not the enum's own "Active" label) to match the
    // reference wording — display-only, the underlying filter is unchanged.
    return filter == OrderFilter.active ? 'Processing' : filter.label;
  }
}

class _FilterSegment extends StatelessWidget {
  const _FilterSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.brandRed : Colors.transparent,
            borderRadius: BorderRadius.circular(100.r),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

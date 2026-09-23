import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:bakaloo_flutter_app/core/utils/extensions/datetime_extensions.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_timeline_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_details/order_detail_palette.dart';

class _Milestone {
  const _Milestone({
    required this.label,
    required this.timestamp,
    required this.isReached,
    required this.isCurrent,
    required this.isCancelledLike,
  });

  final String label;
  final DateTime? timestamp;
  final bool isReached;
  final bool isCurrent;
  final bool isCancelledLike;
}

/// Item 4 — a 4-stage horizontal tracker collapsed from the order's real,
/// much more granular `OrderTimelineType` history (PENDING, CONFIRMED,
/// PREPARING, PACKED, RIDER_ACCEPTED, PICKED_UP, OUT_FOR_DELIVERY,
/// DELIVERED — see order_timeline_entity.dart). Each of the 4 stages below
/// takes the EARLIEST real timestamp among the granular events it groups,
/// so nothing here is invented: a stage with no matching timeline entry
/// yet simply shows no time and renders as not-yet-reached.
class OrderTimeline extends StatelessWidget {
  const OrderTimeline({required this.order, super.key});

  final OrderEntity order;

  @override
  Widget build(BuildContext context) {
    final milestones = _buildMilestones();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List<Widget>.generate(milestones.length * 2 - 1, (index) {
        if (index.isOdd) {
          final leftDone = milestones[(index - 1) ~/ 2].isReached;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 34.h),
              child: Container(
                height: 2,
                color: leftDone
                    ? OrderDetailPalette.primaryRed
                    : OrderDetailPalette.border,
              ),
            ),
          );
        }
        final milestone = milestones[index ~/ 2];
        return _MilestoneColumn(milestone: milestone);
      }),
    );
  }

  List<_Milestone> _buildMilestones() {
    final timelineMap = <OrderTimelineType, DateTime>{};
    for (final item in order.timeline) {
      // Keep the earliest timestamp per type if the backend ever reports
      // one twice — a later duplicate should never win over the real
      // first-reached time.
      timelineMap.putIfAbsent(item.type, () => item.timestamp);
    }

    DateTime? earliestOf(List<OrderTimelineType> types) {
      DateTime? earliest;
      for (final type in types) {
        final ts = timelineMap[type];
        if (ts == null) continue;
        if (earliest == null || ts.isBefore(earliest)) {
          earliest = ts;
        }
      }
      return earliest;
    }

    final placedAt = timelineMap[OrderTimelineType.PENDING] ?? order.createdAt;
    final preparingAt = earliestOf(const <OrderTimelineType>[
      OrderTimelineType.CONFIRMED,
      OrderTimelineType.PREPARING,
    ]);
    final outForDeliveryAt = earliestOf(const <OrderTimelineType>[
      OrderTimelineType.PACKED,
      OrderTimelineType.RIDER_ACCEPTED,
      OrderTimelineType.PICKED_UP,
      OrderTimelineType.OUT_FOR_DELIVERY,
    ]);
    final deliveredAt =
        timelineMap[OrderTimelineType.DELIVERED] ?? order.deliveredAt;

    if (order.status == OrderStatus.CANCELLED ||
        order.status == OrderStatus.REFUNDED) {
      final cancelledAt =
          timelineMap[OrderTimelineType.CANCELLED] ?? order.cancelledAt;
      return <_Milestone>[
        _Milestone(
          label: 'Order Placed',
          timestamp: placedAt,
          isReached: true,
          isCurrent: false,
          isCancelledLike: false,
        ),
        _Milestone(
          label: 'Preparing',
          timestamp: preparingAt,
          isReached: preparingAt != null,
          isCurrent: false,
          isCancelledLike: false,
        ),
        _Milestone(
          label: 'Out for Delivery',
          timestamp: outForDeliveryAt,
          isReached: outForDeliveryAt != null,
          isCurrent: false,
          isCancelledLike: false,
        ),
        _Milestone(
          label: order.status == OrderStatus.REFUNDED
              ? 'Refunded'
              : 'Cancelled',
          timestamp: cancelledAt,
          isReached: true,
          isCurrent: true,
          isCancelledLike: true,
        ),
      ];
    }

    final reachedFlags = <bool>[
      true,
      preparingAt != null || order.status.index > OrderStatus.CONFIRMED.index,
      outForDeliveryAt != null ||
          order.status.index >= OrderStatus.OUT_FOR_DELIVERY.index,
      deliveredAt != null,
    ];
    // The last reached stage is "current" only if the order hasn't reached
    // the final one yet.
    var currentIndex = 0;
    for (var i = 0; i < reachedFlags.length; i++) {
      if (reachedFlags[i]) currentIndex = i;
    }
    final isFullyDelivered = order.status == OrderStatus.DELIVERED;

    return <_Milestone>[
      _Milestone(
        label: 'Order Placed',
        timestamp: placedAt,
        isReached: true,
        isCurrent: currentIndex == 0 && !isFullyDelivered,
        isCancelledLike: false,
      ),
      _Milestone(
        label: 'Preparing',
        timestamp: preparingAt,
        isReached: reachedFlags[1],
        isCurrent: currentIndex == 1 && !isFullyDelivered,
        isCancelledLike: false,
      ),
      _Milestone(
        label: 'Out for Delivery',
        timestamp: outForDeliveryAt,
        isReached: reachedFlags[2],
        isCurrent: currentIndex == 2 && !isFullyDelivered,
        isCancelledLike: false,
      ),
      _Milestone(
        label: 'Delivered',
        timestamp: deliveredAt,
        isReached: reachedFlags[3],
        isCurrent: isFullyDelivered,
        isCancelledLike: false,
      ),
    ];
  }
}

class _MilestoneColumn extends StatelessWidget {
  const _MilestoneColumn({required this.milestone});

  final _Milestone milestone;

  @override
  Widget build(BuildContext context) {
    final accent = milestone.isCancelledLike
        ? const Color(0xFFD32F2F)
        : OrderDetailPalette.primaryRed;

    return SizedBox(
      width: 70.w,
      child: Column(
        children: <Widget>[
          Container(
            width: 24.w,
            height: 24.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: milestone.isReached
                  ? accent
                  : OrderDetailPalette.surfaceMuted,
              border: Border.all(
                color: milestone.isReached
                    ? accent
                    : OrderDetailPalette.border,
                width: milestone.isCurrent ? 2 : 1,
              ),
            ),
            child: milestone.isReached
                ? Icon(
                    milestone.isCancelledLike ? Icons.close : Icons.check,
                    size: 14.sp,
                    color: Colors.white,
                  )
                : null,
          ),
          Gap(8.h),
          Text(
            milestone.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w700,
              color: milestone.isReached
                  ? OrderDetailPalette.textPrimary
                  : OrderDetailPalette.textSecondary,
              height: 1.2,
            ),
          ),
          Gap(2.h),
          Text(
            milestone.timestamp != null
                ? _shortDateTime(milestone.timestamp!)
                : '—',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10.sp,
              fontWeight: FontWeight.w400,
              color: OrderDetailPalette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _shortDateTime(DateTime dt) {
    // Same source-of-truth formatting as the rest of the app
    // (toIndianDateTime), just split across two lines' worth of width.
    final full = dt.toIndianDateTime;
    return full.replaceFirst(' · ', '\n');
  }
}

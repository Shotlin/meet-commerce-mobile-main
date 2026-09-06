// ignore_for_file: constant_identifier_names

import 'package:freezed_annotation/freezed_annotation.dart';

part 'order_timeline_entity.freezed.dart';

enum OrderStatus {
  PENDING,
  CONFIRMED,
  PREPARING,
  PACKED,
  OUT_FOR_DELIVERY,
  DELIVERED,
  CANCELLED,
  REFUNDED,
}

enum OrderTimelineType {
  PENDING,
  CONFIRMED,
  PREPARING,
  PACKED,
  RIDER_ACCEPTED,
  PICKED_UP,
  OUT_FOR_DELIVERY,
  DELIVERED,
  CANCELLED,
  REFUNDED,
}

OrderStatus orderStatusFromRaw(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return OrderStatus.PENDING;
  }

  final normalized = raw.trim().toUpperCase();
  switch (normalized) {
    case 'ACCEPTED':
    case 'RIDER_ACCEPTED':
      return OrderStatus.PACKED;
    case 'PICKED_UP':
    case 'IN_TRANSIT':
      return OrderStatus.OUT_FOR_DELIVERY;
    default:
      for (final status in OrderStatus.values) {
        if (status.name == normalized) {
          return status;
        }
      }
      return OrderStatus.PENDING;
  }
}

OrderTimelineType orderTimelineTypeFromRaw(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return OrderTimelineType.PENDING;
  }

  final normalized = raw.trim().toUpperCase();
  switch (normalized) {
    case 'ACCEPTED':
      return OrderTimelineType.RIDER_ACCEPTED;
    case 'IN_TRANSIT':
      return OrderTimelineType.OUT_FOR_DELIVERY;
    default:
      for (final type in OrderTimelineType.values) {
        if (type.name == normalized) {
          return type;
        }
      }
      return OrderTimelineType.PENDING;
  }
}

OrderStatus orderStatusForTimelineType(OrderTimelineType type) {
  switch (type) {
    case OrderTimelineType.RIDER_ACCEPTED:
      return OrderStatus.PACKED;
    case OrderTimelineType.PICKED_UP:
    case OrderTimelineType.OUT_FOR_DELIVERY:
      return OrderStatus.OUT_FOR_DELIVERY;
    case OrderTimelineType.PENDING:
      return OrderStatus.PENDING;
    case OrderTimelineType.CONFIRMED:
      return OrderStatus.CONFIRMED;
    case OrderTimelineType.PREPARING:
      return OrderStatus.PREPARING;
    case OrderTimelineType.PACKED:
      return OrderStatus.PACKED;
    case OrderTimelineType.DELIVERED:
      return OrderStatus.DELIVERED;
    case OrderTimelineType.CANCELLED:
      return OrderStatus.CANCELLED;
    case OrderTimelineType.REFUNDED:
      return OrderStatus.REFUNDED;
  }
}

OrderTimelineType orderTimelineTypeForStatus(OrderStatus status) {
  switch (status) {
    case OrderStatus.PENDING:
      return OrderTimelineType.PENDING;
    case OrderStatus.CONFIRMED:
      return OrderTimelineType.CONFIRMED;
    case OrderStatus.PREPARING:
      return OrderTimelineType.PREPARING;
    case OrderStatus.PACKED:
      return OrderTimelineType.PACKED;
    case OrderStatus.OUT_FOR_DELIVERY:
      return OrderTimelineType.OUT_FOR_DELIVERY;
    case OrderStatus.DELIVERED:
      return OrderTimelineType.DELIVERED;
    case OrderStatus.CANCELLED:
      return OrderTimelineType.CANCELLED;
    case OrderStatus.REFUNDED:
      return OrderTimelineType.REFUNDED;
  }
}

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
        OrderStatus.PENDING => 'Pending',
        OrderStatus.CONFIRMED => 'Confirmed',
        OrderStatus.PREPARING => 'Preparing',
        OrderStatus.PACKED => 'Packed',
        OrderStatus.OUT_FOR_DELIVERY => 'Out for delivery',
        OrderStatus.DELIVERED => 'Delivered',
        OrderStatus.CANCELLED => 'Cancelled',
        OrderStatus.REFUNDED => 'Refunded',
      };

  bool get isActive => switch (this) {
        OrderStatus.PENDING ||
        OrderStatus.CONFIRMED ||
        OrderStatus.PREPARING ||
        OrderStatus.PACKED ||
        OrderStatus.OUT_FOR_DELIVERY =>
          true,
        OrderStatus.DELIVERED ||
        OrderStatus.CANCELLED ||
        OrderStatus.REFUNDED =>
          false,
      };
}

extension OrderTimelineTypeX on OrderTimelineType {
  String get label => switch (this) {
        OrderTimelineType.PENDING => 'Order placed',
        OrderTimelineType.CONFIRMED => 'Order confirmed',
        OrderTimelineType.PREPARING => 'Preparing order',
        OrderTimelineType.PACKED => 'Packed',
        OrderTimelineType.RIDER_ACCEPTED => 'Rider accepted',
        OrderTimelineType.PICKED_UP => 'Picked up',
        OrderTimelineType.OUT_FOR_DELIVERY => 'Out for delivery',
        OrderTimelineType.DELIVERED => 'Delivered',
        OrderTimelineType.CANCELLED => 'Cancelled',
        OrderTimelineType.REFUNDED => 'Refunded',
      };
}

@freezed
abstract class OrderTimelineEntity with _$OrderTimelineEntity {
  const factory OrderTimelineEntity({
    required OrderTimelineType type,
    required OrderStatus status,
    required DateTime timestamp,
    String? message,
  }) = _OrderTimelineEntity;
}

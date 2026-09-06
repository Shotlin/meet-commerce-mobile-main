import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_timeline_entity.dart';

part 'order_entity.freezed.dart';

@freezed
abstract class OrderEntity with _$OrderEntity {
  const OrderEntity._();

  const factory OrderEntity({
    required String id,
    required String orderNumber,
    required OrderStatus status,
    required List<OrderItemEntity> items,
    required double subtotal,
    required double discount,
    required double deliveryFee,
    required double platformFee,
    required double total,
    required Map<String, dynamic> deliveryAddress,
    required String paymentMethod,
    required String paymentStatus,
    required DateTime createdAt,
    // Wallet-balance toggle checkout feature — the portion of `total`
    // covered by wallet, on top of paymentMethod, regardless of whether
    // that's COD or ONLINE. 0 for orders placed before this feature, or
    // where the customer never used the toggle.
    @Default(0) double walletAmountUsed,
    String? razorpayPaymentId,
    String? couponCode,
    DateTime? deliveredAt,
    DateTime? cancelledAt,
    DateTime? estimatedDelivery,
    @Default(<String, dynamic>{}) Map<String, dynamic> tracking,
    @Default(<OrderTimelineEntity>[]) List<OrderTimelineEntity> timeline,
    // Delivery slot fields
    @Default('ASAP') String deliveryMode,
    String? scheduledSlotLabel,
    DateTime? scheduledSlotStart,
    DateTime? scheduledSlotEnd,
    // 4-digit code the customer reads out to the rider on delivery.
    // Only present while the assignment is ACCEPTED/IN_TRANSIT.
    String? deliveryOtp,
  }) = _OrderEntity;

  List<OrderTimelineEntity> get statusHistory => timeline;

  int get itemCount => items.fold<int>(0, (sum, item) => sum + item.quantity);

  bool get isActive => status.isActive;

  // A Razorpay-expired or verify-failed payment writes exactly
  // status=CANCELLED, paymentStatus IN (FAILED, EXPIRED) — indistinguishable
  // from a plain user/admin cancellation unless this is checked. Derived
  // client-side rather than a new backend OrderStatus value (see
  // order_list_provider.dart's OrderFilter.failed for the matching list
  // filter).
  bool get isPaymentFailed =>
      status == OrderStatus.CANCELLED &&
      const <String>{'FAILED', 'EXPIRED'}.contains(paymentStatus.toUpperCase());
}

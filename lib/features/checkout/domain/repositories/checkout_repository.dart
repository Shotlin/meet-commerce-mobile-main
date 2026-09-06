import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';

class PlaceOrderParams {
  const PlaceOrderParams({
    required this.addressId,
    required this.paymentMethod,
    this.couponCode,
    this.deliveryNotes,
    this.deliveryMode = 'ASAP',
    this.scheduledDeliveryAt,
    this.scheduledSlotStart,
    this.scheduledSlotEnd,
    this.scheduledSlotLabel,
    this.quickDeliverySelected = false,
    this.useWallet = false,
  });

  final String addressId;
  final String paymentMethod;
  final String? couponCode;
  final String? deliveryNotes;
  final String deliveryMode;
  final String? scheduledDeliveryAt;
  final String? scheduledSlotStart;
  final String? scheduledSlotEnd;
  final String? scheduledSlotLabel;
  /// Explicit opt-in only — never implied by `deliveryMode == 'ASAP'` alone.
  final bool quickDeliverySelected;
  /// Explicit opt-in only — applies wallet balance against the total on top
  /// of [paymentMethod] rather than replacing it. Ignored by the backend
  /// when paymentMethod is the legacy 'WALLET'.
  final bool useWallet;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'addressId': addressId,
      'paymentMethod': paymentMethod,
      // Only include couponCode when it's a non-empty string.
      // An empty string fails the backend's minLength:1 schema → "Validation error".
      if (couponCode != null && couponCode!.trim().isNotEmpty)
        'couponCode': couponCode!.trim(),
      if (deliveryNotes != null && deliveryNotes!.trim().isNotEmpty)
        'deliveryNotes': deliveryNotes!.trim(),
      'deliveryMode': deliveryMode,
      if (deliveryMode == 'SCHEDULED') ...{
        if (scheduledDeliveryAt != null) 'scheduledDeliveryAt': scheduledDeliveryAt,
        if (scheduledSlotStart != null) 'scheduledSlotStart': scheduledSlotStart,
        if (scheduledSlotEnd != null) 'scheduledSlotEnd': scheduledSlotEnd,
        if (scheduledSlotLabel != null) 'scheduledSlotLabel': scheduledSlotLabel,
      },
      if (deliveryMode == 'ASAP' && quickDeliverySelected)
        'quickDeliverySelected': true,
      // Always explicit — unlike couponCode/deliveryNotes, false here is a
      // meaningful, deliberate value, not an absent one.
      'useWallet': useWallet,
    };
  }
}

class PlacedOrderEntity {
  const PlacedOrderEntity({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.subtotal,
    required this.discountAmount,
    required this.deliveryFee,
    required this.platformFee,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.createdAt,
    this.couponCode,
    this.estimatedDelivery,
    this.walletAmountUsed = 0,
  });

  final String id;
  final String orderNumber;
  final String status;
  final double subtotal;
  final double discountAmount;
  final double deliveryFee;
  final double platformFee;
  final double totalAmount;
  final String paymentMethod;
  final String paymentStatus;
  final DateTime createdAt;
  final String? couponCode;
  final DateTime? estimatedDelivery;
  final double walletAmountUsed;
}

abstract class CheckoutRepository {
  Future<Either<Failure, PlacedOrderEntity>> placeOrder(
    PlaceOrderParams params,
  );
}

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:bakaloo_flutter_app/features/cart/domain/entities/savings_breakdown_entity.dart';

part 'bill_summary_entity.freezed.dart';
part 'bill_summary_entity.g.dart';

@freezed
abstract class BillSummaryEntity with _$BillSummaryEntity {
  const BillSummaryEntity._();

  const factory BillSummaryEntity({
    required ItemTotal itemTotal,
    required DeliveryFeeInfo deliveryFee,
    required FeeInfo handlingFee,
    required LateNightFeeInfo lateNightFee,
    required BillToPay toPay,
    required SavingsBreakdownEntity savings,
    required DeliveryEstimate deliveryEstimate,
    @Default(0) double couponDiscount,
    @Default(0) double tipAmount,
    @Default(0) int itemCount,
    // ── Canonical dynamic-fee fields (backend TotalsEngine) ──────────
    @Default(FeeInfo()) FeeInfo platformFee,
    @Default(FeeInfo()) FeeInfo smallCartFee,
    @Default(DistanceInfo()) DistanceInfo distance,
    @Default(FreeDeliveryInfo()) FreeDeliveryInfo freeDelivery,
    @Default(0) double totalPayable,
    @Default(<FeeLine>[]) List<FeeLine> fees,
    @Default(PaymentMethodsInfo()) PaymentMethodsInfo paymentMethods,
    @Default(CartMilestoneProgress()) CartMilestoneProgress cartMilestone,
    @Default(QuickDeliveryInfo()) QuickDeliveryInfo quickDelivery,
    FirstTimeOfferInfo? firstTimeOffer,
    FirstTimeOfferTeaserInfo? firstTimeOfferTeaser,
  }) = _BillSummaryEntity;

  factory BillSummaryEntity.fromJson(Map<String, dynamic> json) =>
      _$BillSummaryEntityFromJson(json);

  factory BillSummaryEntity.empty() => const BillSummaryEntity(
        itemTotal: ItemTotal(),
        deliveryFee: DeliveryFeeInfo(),
        handlingFee: FeeInfo(),
        lateNightFee: LateNightFeeInfo(),
        toPay: BillToPay(),
        savings: SavingsBreakdownEntity(),
        deliveryEstimate: DeliveryEstimate(),
      );

  /// The amount the customer pays. Prefers the backend canonical
  /// `totalPayable`; falls back to the legacy `toPay.final` so older
  /// payloads keep working.
  double get payable => totalPayable > 0 ? totalPayable : toPay.finalAmount;
}

@freezed
abstract class ItemTotal with _$ItemTotal {
  const factory ItemTotal({
    @Default(0) double original,
    @Default(0) double discounted,
  }) = _ItemTotal;

  factory ItemTotal.fromJson(Map<String, dynamic> json) =>
      _$ItemTotalFromJson(json);
}

@freezed
abstract class DeliveryFeeInfo with _$DeliveryFeeInfo {
  const factory DeliveryFeeInfo({
    @Default(0) double amount,
    @Default(false) bool isFree,
    @Default(0) double freeIn,
    @Default(0) double originalAmount,
    String? waiverReason,
  }) = _DeliveryFeeInfo;

  factory DeliveryFeeInfo.fromJson(Map<String, dynamic> json) =>
      _$DeliveryFeeInfoFromJson(json);
}

@freezed
abstract class FeeInfo with _$FeeInfo {
  const factory FeeInfo({
    @Default(0) double amount,
    @Default(false) bool isFree,
    @Default(0) double savedAmount,
    // Admin-configurable (dashboard Settings → Fees) — same label/description
    // shown for this fee's admin-set text in the bill's info popup, kept in
    // sync with the dashboard rather than hardcoded per fee in the app.
    String? label,
    String? description,
  }) = _FeeInfo;

  factory FeeInfo.fromJson(Map<String, dynamic> json) =>
      _$FeeInfoFromJson(json);
}

@freezed
abstract class LateNightFeeInfo with _$LateNightFeeInfo {
  const factory LateNightFeeInfo({
    @Default(0) double amount,
    @Default(false) bool isFree,
    @Default(0) double savedAmount,
    @Default(false) bool isLateNight,
  }) = _LateNightFeeInfo;

  factory LateNightFeeInfo.fromJson(Map<String, dynamic> json) =>
      _$LateNightFeeInfoFromJson(json);
}

@freezed
abstract class BillToPay with _$BillToPay {
  const factory BillToPay({
    @Default(0) double original,
    @Default(0) @JsonKey(name: 'final') double finalAmount,
  }) = _BillToPay;

  factory BillToPay.fromJson(Map<String, dynamic> json) =>
      _$BillToPayFromJson(json);
}

@freezed
abstract class DeliveryEstimate with _$DeliveryEstimate {
  const factory DeliveryEstimate({
    @Default(30) int minutes,
    @Default('Delivering in 30 mins') String label,
  }) = _DeliveryEstimate;

  factory DeliveryEstimate.fromJson(Map<String, dynamic> json) =>
      _$DeliveryEstimateFromJson(json);
}

/// Delivery distance from the store to the customer (backend-computed).
@freezed
abstract class DistanceInfo with _$DistanceInfo {
  const factory DistanceInfo({
    double? km,
    @Default('') String label,
    @Default(false) bool known,
  }) = _DistanceInfo;

  factory DistanceInfo.fromJson(Map<String, dynamic> json) =>
      _$DistanceInfoFromJson(json);
}

/// Free-delivery progress info for the customer-facing progress UI.
@freezed
abstract class FreeDeliveryInfo with _$FreeDeliveryInfo {
  const factory FreeDeliveryInfo({
    @Default(false) bool enabled,
    double? threshold,
    @Default(false) bool unlocked,
    @Default(0) double amountToUnlock,
  }) = _FreeDeliveryInfo;

  factory FreeDeliveryInfo.fromJson(Map<String, dynamic> json) =>
      _$FreeDeliveryInfoFromJson(json);
}

/// A single cart-milestone tier as returned by the progress endpoint —
/// either the highest tier already unlocked by the current cart, or the
/// next tier ahead (with `amountToUnlock` filled in for that case).
@freezed
abstract class CartMilestoneTier with _$CartMilestoneTier {
  const factory CartMilestoneTier({
    @Default('') String id,
    @Default('') String name,
    @Default('') String rewardType,
    @Default(0) double minCartAmount,
    @Default(0) double amountToUnlock,
    @Default('') String message,
    String? iconUrl,
    // Only ever populated on the `unlocked` tier of a CASHBACK-type
    // milestone — the wallet credit the customer will actually earn on
    // this order, computed server-side (CartMilestonesService.computeReward).
    @Default(0) double cashbackAmount,
  }) = _CartMilestoneTier;

  factory CartMilestoneTier.fromJson(Map<String, dynamic> json) =>
      _$CartMilestoneTierFromJson(json);
}

/// A single checkpoint in the merged reward ladder (free delivery + every
/// eligible cart-milestone tier, in one ascending sequence). `segmentProgress`
/// is self-contained to this checkpoint's own span — 0 at the previous
/// checkpoint's amount, 1 once this one is reached — so the app can render
/// one continuous segmented progress track instead of a bar that resets to
/// 0% every time a tier is crossed.
@freezed
abstract class CartMilestoneLadderStep with _$CartMilestoneLadderStep {
  const factory CartMilestoneLadderStep({
    @Default('') String id,
    @Default('') String label,
    @Default(0) double minAmount,
    @Default(false) bool achieved,
    @Default(0) double segmentProgress,
  }) = _CartMilestoneLadderStep;

  factory CartMilestoneLadderStep.fromJson(Map<String, dynamic> json) =>
      _$CartMilestoneLadderStepFromJson(json);
}

/// Cart-milestone progress for the customer-facing Smart Bottom Bar —
/// admin-defined cashback/discount/coupon-unlock tiers, independent of the
/// free-delivery threshold above.
@freezed
abstract class CartMilestoneProgress with _$CartMilestoneProgress {
  const factory CartMilestoneProgress({
    CartMilestoneTier? unlocked,
    CartMilestoneTier? next,
    @Default(<CartMilestoneLadderStep>[]) List<CartMilestoneLadderStep> ladder,
  }) = _CartMilestoneProgress;

  factory CartMilestoneProgress.fromJson(Map<String, dynamic> json) =>
      _$CartMilestoneProgressFromJson(json);
}

/// One line in the canonical fee breakdown (delivery / handling / platform / …).
@freezed
abstract class FeeLine with _$FeeLine {
  const factory FeeLine({
    @Default('') String code,
    @Default('') String label,
    @Default(0) double amount,
    @Default(0) double originalAmount,
    @Default(false) bool waived,
    @Default('') String description,
  }) = _FeeLine;

  factory FeeLine.fromJson(Map<String, dynamic> json) =>
      _$FeeLineFromJson(json);
}

/// Cash-on-Delivery availability for the current bill (backend-computed —
/// `enabled` reflects the admin toggle, `available` additionally factors in
/// the live bill total vs. the configured min/max amount).
@freezed
abstract class CodPaymentInfo with _$CodPaymentInfo {
  const factory CodPaymentInfo({
    @Default(true) bool enabled,
    @Default(true) bool available,
    @Default(0) double minAmount,
    double? maxAmount,
    String? reason,
  }) = _CodPaymentInfo;

  factory CodPaymentInfo.fromJson(Map<String, dynamic> json) =>
      _$CodPaymentInfoFromJson(json);
}

/// Simple enable/disable availability for a payment method (Razorpay / Wallet).
@freezed
abstract class MethodAvailability with _$MethodAvailability {
  const factory MethodAvailability({
    @Default(true) bool enabled,
  }) = _MethodAvailability;

  factory MethodAvailability.fromJson(Map<String, dynamic> json) =>
      _$MethodAvailabilityFromJson(json);
}

/// Per-method payment availability for the current bill — drives which
/// payment cards the checkout screen shows/hides/greys out.
@freezed
abstract class PaymentMethodsInfo with _$PaymentMethodsInfo {
  const factory PaymentMethodsInfo({
    @Default(CodPaymentInfo()) CodPaymentInfo cod,
    @Default(MethodAvailability()) MethodAvailability razorpay,
    @Default(MethodAvailability()) MethodAvailability wallet,
  }) = _PaymentMethodsInfo;

  factory PaymentMethodsInfo.fromJson(Map<String, dynamic> json) =>
      _$PaymentMethodsInfoFromJson(json);
}

/// The auto-applied first-order offer (e.g. "Get Rs 51 Veg @ Rs.1"), resolved
/// and priced entirely server-side — unlike a coupon code, it needs no
/// customer action, so it's `null` whenever the customer isn't eligible
/// (not first-time, no matching active offer, or a multi-shop cart). When
/// present, [discount]/[freeDelivery] are already netted into
/// [BillSummaryEntity.totalPayable] / [BillSummaryEntity.couponDiscount].
@freezed
abstract class FirstTimeOfferInfo with _$FirstTimeOfferInfo {
  const factory FirstTimeOfferInfo({
    @Default('') String id,
    @Default('') String name,
    @Default('') String rewardType,
    @Default(0) double discount,
    @Default(false) bool freeDelivery,
    // Only non-zero for rewardType WALLET_CASHBACK — the wallet credit the
    // customer will actually earn on this order.
    @Default(0) double cashbackAmount,
  }) = _FirstTimeOfferInfo;

  factory FirstTimeOfferInfo.fromJson(Map<String, dynamic> json) =>
      _$FirstTimeOfferInfoFromJson(json);
}

/// A nearby-but-not-yet-satisfied first-order offer, surfaced as a positive
/// nudge on the cart screen (e.g. "Add ₹150 of Fresh Vegetables to unlock
/// Free Delivery!") instead of the offer just silently never appearing for
/// a cart that doesn't match its category/product scope. Always `null`
/// whenever [FirstTimeOfferInfo] is already present — the two are mutually
/// exclusive (see bill-summary.service.js).
@freezed
abstract class FirstTimeOfferTeaserInfo with _$FirstTimeOfferTeaserInfo {
  const factory FirstTimeOfferTeaserInfo({
    @Default('') String id,
    @Default('') String name,
    @Default('') String rewardType,
    @Default(0) double amountToUnlock,
    @Default('') String message,
  }) = _FirstTimeOfferTeaserInfo;

  factory FirstTimeOfferTeaserInfo.fromJson(Map<String, dynamic> json) =>
      _$FirstTimeOfferTeaserInfoFromJson(json);
}

/// Whether the paid "Quick Delivery" ASAP upgrade is available right now —
/// independent of whether the customer has actually selected it (that's
/// tracked client-side on [SelectedDeliverySlot], not here). When [enabled]
/// is false the option should not be shown/selectable at all.
@freezed
abstract class QuickDeliveryInfo with _$QuickDeliveryInfo {
  const factory QuickDeliveryInfo({
    @Default(false) bool enabled,
    @Default(0) double amount,
    @Default('Quick delivery fee') String label,

    /// Promised delivery time once the customer opts in — distinct from
    /// the normal always-shown [DeliveryEstimate].
    @Default(0) int etaMinutes,
  }) = _QuickDeliveryInfo;

  factory QuickDeliveryInfo.fromJson(Map<String, dynamic> json) =>
      _$QuickDeliveryInfoFromJson(json);
}

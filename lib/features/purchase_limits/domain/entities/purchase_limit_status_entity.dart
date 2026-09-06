import 'package:freezed_annotation/freezed_annotation.dart';

part 'purchase_limit_status_entity.freezed.dart';

/// Client-side view of an admin-configured "purchase limit rule" as it
/// applies to a single product for the current customer, right now.
///
/// Only ever constructed for a product that IS currently restricted — the
/// backend's `/purchase-limits/my-status` endpoint omits unrestricted
/// products from its response entirely, so the absence of an entity for a
/// given product id (see `purchaseLimitStatusProvider`) is itself the
/// "unrestricted" signal.
@freezed
abstract class PurchaseLimitStatusEntity with _$PurchaseLimitStatusEntity {
  const factory PurchaseLimitStatusEntity({
    required String productId,
    // Already computed server-side as the tighter of the per-order and
    // per-window caps, net of what's currently in the customer's cart —
    // the client only ever needs to read this, never re-derive it.
    required int remainingToAdd,
    required bool isAtLimit,
    String? categoryId,
    String? ruleLabel,
    int? maxQtyPerOrder,
    int? remainingThisOrder,
    bool? windowEnabled,
    String? windowPeriod,
    int? windowCount,
    int? maxQtyPerWindow,
    int? usedInWindow,
    int? remainingInWindow,
  }) = _PurchaseLimitStatusEntity;
}

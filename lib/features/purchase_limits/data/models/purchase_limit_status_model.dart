import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:bakaloo_flutter_app/features/purchase_limits/domain/entities/purchase_limit_status_entity.dart';

part 'purchase_limit_status_model.freezed.dart';
part 'purchase_limit_status_model.g.dart';

/// Mirrors the `items[]` entries of `GET /purchase-limits/my-status`
/// exactly. The backend response is already camelCase JSON, so field names
/// below match the wire format 1:1 with no `@JsonKey(name: ...)` overrides
/// needed (same convention as `unit`/`thumbnailUrl` on `CartItemModel`).
@freezed
abstract class PurchaseLimitStatusModel with _$PurchaseLimitStatusModel {
  const PurchaseLimitStatusModel._();

  const factory PurchaseLimitStatusModel({
    required String productId,
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
  }) = _PurchaseLimitStatusModel;

  factory PurchaseLimitStatusModel.fromJson(Map<String, dynamic> json) =>
      _$PurchaseLimitStatusModelFromJson(json);

  PurchaseLimitStatusEntity toEntity() {
    return PurchaseLimitStatusEntity(
      productId: productId,
      remainingToAdd: remainingToAdd,
      isAtLimit: isAtLimit,
      categoryId: categoryId,
      ruleLabel: ruleLabel,
      maxQtyPerOrder: maxQtyPerOrder,
      remainingThisOrder: remainingThisOrder,
      windowEnabled: windowEnabled,
      windowPeriod: windowPeriod,
      windowCount: windowCount,
      maxQtyPerWindow: maxQtyPerWindow,
      usedInWindow: usedInWindow,
      remainingInWindow: remainingInWindow,
    );
  }
}

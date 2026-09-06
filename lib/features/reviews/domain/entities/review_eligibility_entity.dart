import 'package:freezed_annotation/freezed_annotation.dart';

part 'review_eligibility_entity.freezed.dart';

@freezed
abstract class ReviewEligibilityEntity with _$ReviewEligibilityEntity {
  const factory ReviewEligibilityEntity({
    required bool canReview,
    String? reason,
    String? orderId,
  }) = _ReviewEligibilityEntity;
}

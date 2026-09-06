import 'package:freezed_annotation/freezed_annotation.dart';

part 'review_entity.freezed.dart';

@freezed
abstract class ReviewEntity with _$ReviewEntity {
  const factory ReviewEntity({
    required String id,
    required int rating,
    required DateTime createdAt,
    String? productId,
    String? orderId,
    String? comment,
    String? userName,
    String? productName,
    String? productImage,
  }) = _ReviewEntity;
}

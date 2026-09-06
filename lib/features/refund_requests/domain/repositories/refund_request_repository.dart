import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/refund_requests/domain/entities/refund_request_status_entity.dart';

class RefundRequestCreateParams {
  const RefundRequestCreateParams({
    required this.orderId,
    required this.itemScope,
    required this.description,
    this.productIds,
  });

  final String orderId;

  /// 'ALL' or 'SPECIFIC'.
  final String itemScope;
  final String description;
  final List<String>? productIds;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'orderId': orderId,
      'itemScope': itemScope,
      'description': description,
      'productIds': productIds,
    }..removeWhere((key, value) => value == null);
  }
}

abstract class RefundRequestRepository {
  Future<Either<Failure, void>> createRequest(
    RefundRequestCreateParams params,
  );

  /// The latest refund request for this order, or null if none exists yet.
  Future<Either<Failure, RefundRequestStatusEntity?>> getByOrder(
    String orderId,
  );

  Future<Either<Failure, void>> cancelRequest(String requestId);
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/refund_requests/data/datasources/refund_request_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/refund_requests/data/repositories/refund_request_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/refund_requests/domain/entities/refund_request_status_entity.dart';
import 'package:bakaloo_flutter_app/features/refund_requests/domain/repositories/refund_request_repository.dart';
import 'package:bakaloo_flutter_app/features/refund_requests/domain/usecases/cancel.dart';
import 'package:bakaloo_flutter_app/features/refund_requests/domain/usecases/create.dart';
import 'package:bakaloo_flutter_app/features/refund_requests/domain/usecases/get_by_order.dart';

part 'refund_request_provider.g.dart';

class RefundRequestActionResult {
  const RefundRequestActionResult({this.failure});

  final Failure? failure;

  bool get isSuccess => failure == null;
}

final refundRequestRemoteDataSourceProvider =
    Provider<RefundRequestRemoteDataSource>((Ref ref) {
  return RefundRequestRemoteDataSource(ref.watch(apiClientProvider));
});

final refundRequestRepositoryProvider =
    Provider<RefundRequestRepository>((Ref ref) {
  return RefundRequestRepositoryImpl(
    remoteDataSource: ref.watch(refundRequestRemoteDataSourceProvider),
  );
});

final createRefundRequestUseCaseProvider =
    Provider<CreateRefundRequestUseCase>((Ref ref) {
  return CreateRefundRequestUseCase(ref.watch(refundRequestRepositoryProvider));
});

final getRefundRequestByOrderUseCaseProvider =
    Provider<GetRefundRequestByOrderUseCase>((Ref ref) {
  return GetRefundRequestByOrderUseCase(ref.watch(refundRequestRepositoryProvider));
});

final cancelRefundRequestUseCaseProvider =
    Provider<CancelRefundRequestUseCase>((Ref ref) {
  return CancelRefundRequestUseCase(ref.watch(refundRequestRepositoryProvider));
});

/// The latest refund request for one order — null when none exists yet.
/// Drives the order-detail screen's status card and whether "Request
/// Refund" should still be offered.
@riverpod
Future<RefundRequestStatusEntity?> refundRequestByOrder(
  Ref ref,
  String orderId,
) async {
  final result =
      await ref.read(getRefundRequestByOrderUseCaseProvider).call(orderId);
  return result.fold(
    (failure) => throw StateError(failure.message),
    (status) => status,
  );
}

@Riverpod(keepAlive: true)
class RefundRequestNotifier extends _$RefundRequestNotifier {
  @override
  AsyncValue<void> build() {
    return const AsyncData(null);
  }

  Future<RefundRequestActionResult> createRequest(
    RefundRequestCreateParams params,
  ) async {
    state = const AsyncLoading<void>();
    final result =
        await ref.read(createRefundRequestUseCaseProvider).call(params);
    return result.fold(
      (failure) {
        state = AsyncError<void>(failure, StackTrace.current);
        return RefundRequestActionResult(failure: failure);
      },
      (_) {
        state = const AsyncData<void>(null);
        return const RefundRequestActionResult();
      },
    );
  }

  Future<RefundRequestActionResult> cancelRequest(String requestId) async {
    state = const AsyncLoading<void>();
    final result =
        await ref.read(cancelRefundRequestUseCaseProvider).call(requestId);
    return result.fold(
      (failure) {
        state = AsyncError<void>(failure, StackTrace.current);
        return RefundRequestActionResult(failure: failure);
      },
      (_) {
        state = const AsyncData<void>(null);
        return const RefundRequestActionResult();
      },
    );
  }
}

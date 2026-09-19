import 'dart:async';

import 'package:dio/dio.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/analytics/analytics_service.dart';
import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/features/auth/domain/entities/user_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_enhancement_providers.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/checkout_provider.dart';
import 'package:bakaloo_flutter_app/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/entities/payment_entity.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/entities/razorpay_order_entity.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/repositories/payment_repository.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/usecases/create_payment_order.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/usecases/get_history.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/usecases/verify_payment.dart';
import 'package:bakaloo_flutter_app/features/payments/presentation/service/razorpay_service.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:bakaloo_flutter_app/routing/app_router.dart';

part 'payment_provider.freezed.dart';
part 'payment_provider.g.dart';

@freezed
abstract class PaymentState with _$PaymentState {
  const factory PaymentState({
    @Default(false) bool isLoading,
    @Default(false) bool isVerifying,
    // Set while the checkout SDK has reported an error that ISN'T a
    // confirmed user cancellation and we're checking with the backend
    // before deciding anything — and again, with a different
    // [pendingMessage], if that check exhausts its bounded wait with no
    // definitive answer yet. Never means "failed"; the UI must not show a
    // dead-end error while this is true.
    @Default(false) bool isPendingConfirmation,
    String? pendingMessage,
    String? errorMessage,
    PaymentEntity? lastPayment,
    String? activeOrderId,
    String? activeRazorpayOrderId,
    @Default(false) bool isWalletTopupFlow,
  }) = _PaymentState;

  factory PaymentState.idle() => const PaymentState();
}

class PaymentActionResult {
  const PaymentActionResult({
    this.errorMessage,
  });

  final String? errorMessage;

  bool get isSuccess => errorMessage == null;
}

final paymentRemoteDataSourceProvider = Provider<PaymentRemoteDataSource>((
  Ref ref,
) {
  return PaymentRemoteDataSource(ref.watch(apiClientProvider));
});

final paymentRepositoryProvider = Provider<PaymentRepository>((Ref ref) {
  return PaymentRepositoryImpl(
    remoteDataSource: ref.watch(paymentRemoteDataSourceProvider),
  );
});

final createPaymentOrderUseCaseProvider = Provider<CreatePaymentOrderUseCase>((
  Ref ref,
) {
  return CreatePaymentOrderUseCase(ref.watch(paymentRepositoryProvider));
});

final verifyPaymentUseCaseProvider = Provider<VerifyPaymentUseCase>((Ref ref) {
  return VerifyPaymentUseCase(ref.watch(paymentRepositoryProvider));
});

final getPaymentHistoryUseCaseProvider = Provider<GetHistoryUseCase>((Ref ref) {
  return GetHistoryUseCase(ref.watch(paymentRepositoryProvider));
});

final razorpayServiceProvider = Provider<RazorpayService>((Ref ref) {
  final service = RazorpayService();
  ref.onDispose(service.dispose);
  return service;
});

@Riverpod(keepAlive: true)
Future<double> walletBalance(Ref ref) async {
  final result = await ref.read(paymentRepositoryProvider).getWalletBalance();
  return result.fold((failure) {
    throw StateError(failure.message);
  }, (balance) {
    return balance;
  });
}

@Riverpod(keepAlive: true)
class PaymentNotifier extends _$PaymentNotifier {
  RazorpayService get _razorpayService => ref.read(razorpayServiceProvider);

  PaymentRepository get _repository => ref.read(paymentRepositoryProvider);

  UserEntity? get _currentUser => ref.read(currentUserProvider);

  @override
  PaymentState build() {
    ref.onDispose(_resetCallbacks);
    return PaymentState.idle();
  }

  Future<PaymentActionResult> startRazorpayFlow(
    PlacedOrderEntity order,
  ) async {
    if (state.isLoading || state.isVerifying) {
      const message = 'A payment is already in progress.';
      state = state.copyWith(errorMessage: message);
      return const PaymentActionResult(errorMessage: message);
    }
    if (!_razorpayService.isSupported) {
      const message =
          'Online payment checkout is not configured for this browser.';
      state = PaymentState.idle().copyWith(errorMessage: message);
      return const PaymentActionResult(errorMessage: message);
    }

    state = state.copyWith(
      isLoading: true,
      isVerifying: false,
      errorMessage: null,
      activeOrderId: order.id,
      isWalletTopupFlow: false,
    );

    final result = await ref.read(createPaymentOrderUseCaseProvider).call(
          order.id,
        );

    return result.fold(
      (failure) {
        state = PaymentState.idle().copyWith(errorMessage: failure.message);
        return PaymentActionResult(errorMessage: failure.message);
      },
      (razorpayOrder) {
        final validationMessage = _validateRazorpayOrder(razorpayOrder);
        if (validationMessage != null) {
          state = PaymentState.idle().copyWith(errorMessage: validationMessage);
          return PaymentActionResult(errorMessage: validationMessage);
        }

        _attachOrderCallbacks(
          orderId: order.id,
          razorpayOrderId: razorpayOrder.razorpayOrderId,
        );

        try {
          _razorpayService.open(
            RazorpayOptions(
              key: razorpayOrder.key,
              amount: razorpayOrder.amount,
              razorpayOrderId: razorpayOrder.razorpayOrderId,
              name: 'Bakaloo',
              description: 'Order #${order.orderNumber}',
              contact: _currentUser?.phone,
              email: _currentUser?.email,
              prefillName: _currentUser?.name,
              themeColorHex: '#0C831F',
            ),
          );
          state = state.copyWith(
            isLoading: false,
            activeRazorpayOrderId: razorpayOrder.razorpayOrderId,
          );
          return const PaymentActionResult();
        } catch (_) {
          const message = 'Unable to open Razorpay right now.';
          state = PaymentState.idle().copyWith(errorMessage: message);
          return const PaymentActionResult(errorMessage: message);
        }
      },
    );
  }

  Future<PaymentActionResult> startWalletTopup({
    required double amount,
  }) async {
    if (state.isLoading || state.isVerifying) {
      const message = 'A payment is already in progress.';
      state = state.copyWith(errorMessage: message);
      return const PaymentActionResult(errorMessage: message);
    }
    if (!_razorpayService.isSupported) {
      const message =
          'Online payment checkout is not configured for this browser.';
      state = PaymentState.idle().copyWith(errorMessage: message);
      return const PaymentActionResult(errorMessage: message);
    }

    state = state.copyWith(
      isLoading: true,
      isVerifying: false,
      errorMessage: null,
      activeOrderId: null,
      isWalletTopupFlow: true,
    );

    final result = await _repository.createWalletTopup(
      WalletTopupParams(amount: amount),
    );

    return result.fold(
      (failure) {
        state = PaymentState.idle().copyWith(errorMessage: failure.message);
        return PaymentActionResult(errorMessage: failure.message);
      },
      (razorpayOrder) {
        final validationMessage = _validateRazorpayOrder(razorpayOrder);
        if (validationMessage != null) {
          state = PaymentState.idle().copyWith(errorMessage: validationMessage);
          return PaymentActionResult(errorMessage: validationMessage);
        }

        _attachTopupCallbacks(razorpayOrderId: razorpayOrder.razorpayOrderId);

        try {
          _razorpayService.open(
            RazorpayOptions(
              key: razorpayOrder.key,
              amount: razorpayOrder.amount,
              razorpayOrderId: razorpayOrder.razorpayOrderId,
              name: 'Bakaloo',
              description: 'Wallet Top-up',
              contact: _currentUser?.phone,
              email: _currentUser?.email,
              prefillName: _currentUser?.name,
              themeColorHex: '#0C831F',
            ),
          );
          state = state.copyWith(
            isLoading: false,
            activeRazorpayOrderId: razorpayOrder.razorpayOrderId,
          );
          return const PaymentActionResult();
        } catch (_) {
          const message = 'Unable to open Razorpay right now.';
          state = PaymentState.idle().copyWith(errorMessage: message);
          return const PaymentActionResult(errorMessage: message);
        }
      },
    );
  }

  void clearError() {
    if (state.errorMessage == null) {
      return;
    }
    state = state.copyWith(errorMessage: null);
  }

  void _attachOrderCallbacks({
    required String orderId,
    required String razorpayOrderId,
  }) {
    _razorpayService
      ..onSuccess = (response) {
        unawaited(
          _verifyPayment(
            orderId: orderId,
            razorpayOrderId: razorpayOrderId,
            response: response,
          ),
        );
      }
      ..onFailure = _handleFailure
      // Handing off to an external wallet app (PayZapp, Airtel Money, etc.)
      // is a dead end for the SDK callbacks — neither onSuccess nor
      // onFailure fires once the wallet app takes over, so this attempt's
      // outcome can ONLY ever be learned by asking the backend. Previously
      // this just reset to idle, silently dropping any signal of an
      // in-flight payment the moment the wallet app opened.
      ..onExternalWallet = () {
        _beginPendingConfirmation(
          orderId: orderId,
          razorpayOrderId: razorpayOrderId,
        );
      };
  }

  void _attachTopupCallbacks({
    required String razorpayOrderId,
  }) {
    _razorpayService
      ..onSuccess = (response) {
        unawaited(
          _verifyWalletTopup(
            orderId: razorpayOrderId,
            response: response,
          ),
        );
      }
      ..onFailure = _handleFailure
      ..onExternalWallet = () {
        state = state.copyWith(isLoading: false);
      };
  }

  Future<void> _verifyPayment({
    required String orderId,
    required String razorpayOrderId,
    required RazorpayPaymentSuccess response,
  }) async {
    final paymentId = response.paymentId;
    final signature = response.signature;
    if (paymentId == null || signature == null) {
      // A complete callback is required for server verification, but a
      // malformed/partial callback is still ambiguous: Razorpay may have
      // captured the payment before the browser lost or corrupted the
      // payload. Keep the order locked and ask the authoritative status
      // endpoint instead of unlocking the cart or presenting a terminal
      // failure that could prompt a duplicate charge.
      _beginPendingConfirmation(
        orderId: orderId,
        razorpayOrderId: razorpayOrderId,
      );
      return;
    }

    state = state.copyWith(
      isLoading: false,
      isVerifying: true,
      errorMessage: null,
    );

    final result = await ref.read(verifyPaymentUseCaseProvider).call(
          PaymentVerificationParams(
            orderId: orderId,
            razorpayOrderId: razorpayOrderId,
            paymentId: paymentId,
            signature: signature,
          ),
        );

    result.fold(
      (failure) {
        // The backend may have rejected the callback after checking Razorpay
        // (and can already have moved the payment to FAILED), or the request
        // may have failed in transit. In either case the client must not
        // unlock the order and invite a second payment until the backend's
        // status endpoint gives a definitive answer.
        _beginPendingConfirmation(
          orderId: orderId,
          razorpayOrderId: razorpayOrderId,
        );
      },
      (payment) {
        ref.invalidate(cartProvider); // Clear cart ONLY after confirmed payment
        // A partial wallet + online order deducted the wallet slice the
        // instant the order was placed, before Razorpay ever opened — read
        // useWallet before resetForNewOrder() clears it below.
        if (ref.read(checkoutProvider).useWallet) {
          ref.invalidate(walletProvider);
        }
        ref.read(checkoutProvider.notifier).resetForNewOrder();
        state = PaymentState.idle().copyWith(lastPayment: payment);
        unawaited(
          ref.read(analyticsServiceProvider).logPurchase(
                orderId,
                payment.amount,
                (payment.method ?? 'ONLINE').toUpperCase(),
              ),
        );
        ref.read(appRouterProvider).go('/orders/success/$orderId');
      },
    );
  }

  Future<void> _verifyWalletTopup({
    required String orderId,
    required RazorpayPaymentSuccess response,
  }) async {
    final paymentId = response.paymentId;
    final signature = response.signature;
    if (paymentId == null || signature == null) {
      state = PaymentState.idle().copyWith(
        errorMessage: 'Top-up verification details are missing.',
      );
      return;
    }

    state = state.copyWith(
      isLoading: false,
      isVerifying: true,
      errorMessage: null,
    );

    final result = await _repository.verifyWalletTopup(
      WalletTopupVerificationParams(
        paymentId: paymentId,
        orderId: orderId,
        signature: signature,
      ),
    );

    result.fold(
      (failure) {
        state = PaymentState.idle().copyWith(errorMessage: failure.message);
      },
      (_) {
        ref.invalidate(walletBalanceProvider);
        state = PaymentState.idle();
      },
    );
  }

  /// Only `PAYMENT_CANCELLED` is Razorpay's own unambiguous "the user
  /// backed out" signal. Every other code — `NETWORK_ERROR`, `TLS_ERROR`,
  /// `UNKNOWN_ERROR`, and even a blank/missing message — means Razorpay's
  /// own checkout couldn't confirm what happened, NOT that the payment
  /// failed. The bank/UPI side can already have succeeded (this is exactly
  /// the "paid but shows failed" bug): declaring failure on this signal
  /// alone and immediately cancelling, as this used to do unconditionally,
  /// is the root cause. Only a confirmed cancellation short-circuits
  /// straight to cancelling; everything else goes through
  /// [_beginPendingConfirmation] to ask the backend first.
  void _handleFailure(RazorpayPaymentFailure response) {
    final orderId = state.activeOrderId;
    final razorpayOrderId = state.activeRazorpayOrderId;

    if (response.code == RazorpayPaymentFailure.paymentCancelled) {
      unawaited(_finishCancelledPayment(orderId));
      return;
    }

    if (orderId == null || razorpayOrderId == null) {
      // No in-flight order to check against — nothing left to do but
      // surface a generic failure (this shouldn't normally happen, since
      // both are set before Razorpay Checkout ever opens).
      state = PaymentState.idle().copyWith(
        errorMessage: 'Payment failed. Please try again.',
      );
      return;
    }

    _beginPendingConfirmation(
        orderId: orderId, razorpayOrderId: razorpayOrderId);
  }

  /// Keeps the checkout/cart screen locked — reusing the same "pending
  /// confirmation" banner/spinner as an ambiguous payment result — until
  /// the order is genuinely confirmed cancelled server-side, instead of
  /// unlocking immediately and racing that confirmation.
  ///
  /// BUG FIX: this used to fire the cancel unawaited and flip straight to
  /// PaymentState.idle() — the instant Razorpay reported the cancellation,
  /// before the backend had actually cancelled anything. orders.service.js
  /// #cancel() genuinely can't skip verifying with Razorpay first (a
  /// deliberate safety check — see its own doc comment — that stops a
  /// payment Razorpay actually captured from being silently orphaned), so
  /// that confirmation takes a real, if usually brief, network round trip.
  /// Unlocking before it finished meant leaving this screen in that window
  /// (checkout_screen.dart's dispose() refreshes cartProvider, which
  /// billSummaryProvider watches) read the order while it was still
  /// PENDING server-side — full, undiscounted total for a moment, then a
  /// second, correct refresh once _cancelPendingOrder's own invalidate
  /// finally landed. Reported as: cancelling a first-time-offer order's
  /// payment briefly "fluctuates" to the full price before resetting.
  /// Nothing here unlocks until that's already settled, so there's no
  /// window left for anything to read the stale value.
  Future<void> _finishCancelledPayment(String? orderId) async {
    if (orderId != null) {
      state = state.copyWith(
        isLoading: false,
        isPendingConfirmation: true,
        pendingMessage: 'Cancelling your order…',
        errorMessage: null,
      );
      final paymentConfirmed = await _cancelPendingOrder(
        orderId,
        reason: 'Payment cancelled by user',
      );
      if (paymentConfirmed) {
        return;
      }
    }
    state = PaymentState.idle().copyWith(
      errorMessage: 'Payment cancelled. You can try again.',
    );
  }

  void _beginPendingConfirmation({
    required String orderId,
    required String razorpayOrderId,
  }) {
    state = state.copyWith(
      isLoading: false,
      isVerifying: false,
      isPendingConfirmation: true,
      pendingMessage: 'Verifying your payment…',
      errorMessage: null,
    );
    unawaited(
      _pollPaymentStatus(orderId: orderId, razorpayOrderId: razorpayOrderId),
    );
  }

  /// Bounded poll (~90s total) against the backend's authoritative status
  /// for this Razorpay order, mirroring the wait-with-attempts-cap idiom
  /// already used for the APNs-token race in fcm_token_helper.dart. Never
  /// declares failure on its own timing out — if the backend still can't
  /// say for certain, this leaves the order exactly as-is so the backend's
  /// own reconciliation (webhook / expiry-worker sweep) can resolve it
  /// later; the customer is notified whenever that happens.
  static const List<int> _pollDelaysMs = <int>[
    0,
    3000,
    6000,
    12000,
    24000,
    45000
  ];

  Future<void> _pollPaymentStatus({
    required String orderId,
    required String razorpayOrderId,
  }) async {
    for (final delayMs in _pollDelaysMs) {
      if (delayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
      // A newer checkout attempt (or another caller of recheckIfPending())
      // has already moved past this one — stop, don't stomp on it.
      if (state.activeRazorpayOrderId != razorpayOrderId) {
        return;
      }

      PaymentStatusResult? status;
      try {
        final result = await _repository.getPaymentStatus(razorpayOrderId);
        status = result.fold((_) => null, (value) => value);
      } catch (_) {
        status = null;
      }

      if (status == null) {
        continue; // transient error or "not found yet" — keep polling
      }
      if (status.isPaid) {
        unawaited(_onPaymentConfirmed(orderId: orderId));
        return;
      }
      if (status.isFailed) {
        await _onPaymentDefinitivelyFailed(
          orderId: orderId,
          reason: status.displayReason,
        );
        return;
      }
      // Still PENDING per the backend — keep polling.
    }

    if (state.activeRazorpayOrderId == razorpayOrderId) {
      state = state.copyWith(
        isPendingConfirmation: true,
        pendingMessage: "We're still confirming your payment with the bank. "
            "This can take a few minutes — you'll get a notification and "
            "your order will appear automatically. Please don't pay again.",
      );
    }
  }

  /// Re-check now, e.g. when the app resumes from being backgrounded while
  /// a UPI/wallet app had control — the checkout screen calls this from
  /// its lifecycle observer so a payment left in limbo by an OS-killed
  /// activity doesn't just sit there until the poll's own next tick.
  void recheckIfPending() {
    final orderId = state.activeOrderId;
    final razorpayOrderId = state.activeRazorpayOrderId;
    if (!state.isPendingConfirmation ||
        orderId == null ||
        razorpayOrderId == null) {
      return;
    }
    unawaited(
      _pollPaymentStatus(orderId: orderId, razorpayOrderId: razorpayOrderId),
    );
  }

  Future<void> _onPaymentConfirmed({required String orderId}) async {
    ref.invalidate(cartProvider); // Clear cart ONLY after confirmed payment
    // Same reasoning as _verifyPayment above — read useWallet before
    // resetForNewOrder() clears it.
    if (ref.read(checkoutProvider).useWallet) {
      ref.invalidate(walletProvider);
    }
    ref.read(checkoutProvider.notifier).resetForNewOrder();
    state = PaymentState.idle();
    ref.read(appRouterProvider).go('/orders/success/$orderId');
  }

  /// Same reasoning as _finishCancelledPayment above — stays locked (already
  /// isPendingConfirmation from _beginPendingConfirmation, just refreshing
  /// the message) until the order is actually cancelled server-side,
  /// instead of unlocking and racing that confirmation.
  Future<void> _onPaymentDefinitivelyFailed({
    required String orderId,
    String? reason,
  }) async {
    state = state.copyWith(pendingMessage: 'Cancelling your order…');
    final paymentConfirmed = await _cancelPendingOrder(
      orderId,
      reason: reason == null ? 'Payment failed' : 'Payment failed: $reason',
    );
    if (paymentConfirmed) {
      return;
    }
    state = PaymentState.idle().copyWith(
      errorMessage: reason ?? 'Payment failed. Please try again.',
    );
  }

  /// Returns true when the backend says the order was actually paid while
  /// cancellation was being reconciled. Awaiting [_onPaymentConfirmed] is
  /// important: otherwise the caller could immediately overwrite the success
  /// state with a contradictory cancellation/failure message.
  Future<bool> _cancelPendingOrder(
    String orderId, {
    required String reason,
  }) async {
    try {
      final cancelResponse = await ref.read(dioClientProvider).post<dynamic>(
        ApiConstants.orderCancel(orderId),
        data: <String, dynamic>{'reason': reason},
      );
      if (_isPaymentConfirmedResponse(cancelResponse.data)) {
        await _onPaymentConfirmed(orderId: orderId);
        return true;
      }
      await ref.read(dioClientProvider).post<dynamic>(
        ApiConstants.orderReorder(orderId),
        data: const <String, dynamic>{},
      );
    } on DioException catch (error) {
      // The backend refuses to cancel (and confirms the order instead) when
      // its own live Razorpay check finds the payment was actually
      // captured — signalled by a 409 with `paymentConfirmed: true` in the
      // body. Previously this response was discarded entirely (any
      // non-2xx just landed in a silent catch-all), so that save was
      // invisible here and nothing ever stopped the customer's cart from
      // being restored on top of an order that had actually succeeded.
      if (_isPaymentConfirmedResponse(error.response?.data)) {
        await _onPaymentConfirmed(orderId: orderId);
        return true;
      }
      // Any other failure: silent fail — backend auto-cancels unpaid
      // orders after timeout. Best effort only. If reorder fails, the
      // existing cart state in memory still lets the user retry without
      // getting stuck on a blank flow.
    } catch (_) {
      // Non-Dio failure — same best-effort reasoning as above.
    } finally {
      // BUG FIX: a cancelled-before-payment order (Razorpay dismissed/
      // cancelled, or _onPaymentDefinitivelyFailed) is exactly the case
      // FirstTimeOffersRepository#hasPriorOrder excludes (it only counts
      // orders with status != 'CANCELLED') — so once this order is
      // actually cancelled on the backend, a first-time customer's offer
      // becomes available again. But nothing here ever told
      // billSummaryProvider to re-fetch, so the checkout/cart screen kept
      // showing whatever total it had cached from BEFORE this cancel call
      // even completed — which, if the customer glanced back at the price
      // while this request was still in flight, could be the full
      // undiscounted total (order still PENDING at that instant), and
      // then never correct itself since nothing re-triggered a fetch
      // afterward either. Reported as: cancel a first Razorpay payment,
      // price permanently shows the normal (non-first-time-offer) total.
      // Invalidating here — regardless of outcome above — means the very
      // next time the cart/checkout screen is looked at, it reflects
      // whatever the backend now actually has, not a stale pre-cancel
      // snapshot.
      ref.invalidate(billSummaryProvider);
    }
    return false;
  }

  bool _isPaymentConfirmedResponse(dynamic data) {
    return data is Map && data['paymentConfirmed'] == true;
  }

  void _resetCallbacks() {
    _razorpayService
      ..onSuccess = null
      ..onFailure = null
      ..onExternalWallet = null;
  }

  String? _validateRazorpayOrder(RazorpayOrderEntity order) {
    if (order.key.trim().isEmpty) {
      return 'Online payment is not configured. Please try wallet payment.';
    }
    if (order.razorpayOrderId.trim().isEmpty) {
      return 'Payment order ID is missing. Please try again.';
    }
    if (order.amount <= 0) {
      return 'Invalid payment amount received. Please try again.';
    }
    return null;
  }
}

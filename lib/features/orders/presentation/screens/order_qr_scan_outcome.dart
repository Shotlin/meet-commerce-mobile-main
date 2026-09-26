import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_details/order_qr_payload_parser.dart';

/// The result of validating one scanned QR against the order the scanner
/// was opened from — pulled out of `OrderQrScanScreen`'s `_onDetect` as a
/// pure function so this decision (the actual security-relevant bit) is
/// directly unit-testable without needing a real camera/`mobile_scanner`
/// platform implementation.
sealed class QrScanOutcome {
  const QrScanOutcome();
}

/// The scanned code is a real FreshCuts order QR AND matches the order the
/// scanner was opened from (or no order was in scope to check against) —
/// safe to navigate to that order's Quality Video screen.
class QrScanMatch extends QrScanOutcome {
  const QrScanMatch(this.orderId);
  final String orderId;
}

/// The scanned text isn't a recognisable FreshCuts order QR at all, or it
/// names a genuinely different order than the one this scanner was opened
/// from — in both cases nothing opens, the camera keeps running, and
/// [message] is shown so the customer can immediately try again.
class QrScanRejected extends QrScanOutcome {
  const QrScanRejected(this.message);
  final String message;
}

/// @param rawValue the raw scanned barcode text (or null if nothing decoded)
/// @param expectedOrderId the real `orders.id` of the order the scanner was
///   opened from; null only for the defensive "no order in scope" fallback
/// @param expectedOrderNumber the human-readable order number, used only to
///   make the rejection message name the order the customer is actually in
QrScanOutcome resolveQrScanOutcome({
  required String? rawValue,
  required String? expectedOrderId,
  required String? expectedOrderNumber,
}) {
  final orderId = parseFreshCutsOrderQrPayload(rawValue);

  if (orderId == null) {
    return const QrScanRejected("That doesn't look like a FreshCuts order QR — try again.");
  }

  if (expectedOrderId != null && orderId != expectedOrderId) {
    return QrScanRejected(
      expectedOrderNumber != null
          ? 'This QR code belongs to a different order — not $expectedOrderNumber.'
          : 'This QR code belongs to a different order.',
    );
  }

  return QrScanMatch(orderId);
}

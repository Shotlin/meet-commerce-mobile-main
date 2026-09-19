import 'dart:convert';
import 'dart:js_interop';

@JS('bakalooCheckoutOpen')
external void _openCheckout(
  JSString options,
  JSFunction success,
  JSFunction failure,
);
@JS('bakalooCheckoutDispose')
external void _disposeCheckout();

/// Official Razorpay Standard Checkout. Callbacks only supply verification
/// details; the shared backend verification/status flow decides payment state.
class RazorpayService {
  bool get isSupported => true;
  void Function(RazorpayPaymentSuccess)? onSuccess;
  void Function(RazorpayPaymentFailure)? onFailure;
  void Function()? onExternalWallet;

  void open(RazorpayOptions options) {
    _openCheckout(
      jsonEncode(<String, dynamic>{
        'key': options.key,
        'amount': options.amount,
        'currency': 'INR',
        'order_id': options.razorpayOrderId,
        'name': options.name,
        'description': options.description,
        'prefill': <String, String?>{
          'contact': options.contact,
          'email': options.email,
          'name': options.prefillName,
        }..removeWhere((key, value) => value == null || value.isEmpty),
        'theme': <String, String>{'color': options.themeColorHex},
      }).toJS,
      ((JSString result) {
        final data = jsonDecode(result.toDart) as Map<String, dynamic>;
        onSuccess?.call(RazorpayPaymentSuccess(
          paymentId: data['paymentId'] as String?,
          signature: data['signature'] as String?,
        ));
      }).toJS,
      ((JSNumber code) {
        onFailure?.call(RazorpayPaymentFailure(code: code.toDartInt));
      }).toJS,
    );
  }

  void dispose() {
    _disposeCheckout();
    onSuccess = null;
    onFailure = null;
    onExternalWallet = null;
  }
}

class RazorpayPaymentSuccess {
  const RazorpayPaymentSuccess({
    required this.paymentId,
    required this.signature,
  });

  final String? paymentId;
  final String? signature;
}

class RazorpayPaymentFailure {
  const RazorpayPaymentFailure({required this.code});

  static const int paymentCancelled = 0;
  final int code;
}

class RazorpayOptions {
  const RazorpayOptions({
    required this.key,
    required this.amount,
    required this.razorpayOrderId,
    required this.name,
    required this.description,
    required this.themeColorHex,
    this.contact,
    this.email,
    this.prefillName,
  });

  final String key;
  final int amount;
  final String razorpayOrderId;
  final String name;
  final String description;
  final String themeColorHex;
  final String? contact;
  final String? email;
  final String? prefillName;
}

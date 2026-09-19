import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayService {
  RazorpayService() {
    _razorpay
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _handleFailure)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _handleWallet);
  }

  final Razorpay _razorpay = Razorpay();

  bool get isSupported => true;
  void Function(RazorpayPaymentSuccess)? onSuccess;
  void Function(RazorpayPaymentFailure)? onFailure;
  void Function()? onExternalWallet;

  void open(RazorpayOptions options) => _razorpay.open(options.toMap());

  void dispose() => _razorpay.clear();

  void _handleSuccess(PaymentSuccessResponse response) {
    onSuccess?.call(
      RazorpayPaymentSuccess(
        paymentId: response.paymentId,
        signature: response.signature,
      ),
    );
  }

  void _handleFailure(PaymentFailureResponse response) {
    onFailure?.call(RazorpayPaymentFailure(code: response.code ?? -1));
  }

  void _handleWallet(ExternalWalletResponse response) {
    onExternalWallet?.call();
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

  static const int paymentCancelled = Razorpay.PAYMENT_CANCELLED;
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

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'key': key,
      'amount': amount,
      'order_id': razorpayOrderId,
      'name': name,
      'description': description,
      'prefill': <String, dynamic>{
        'contact': contact,
        'email': email,
        'name': prefillName,
      }..removeWhere((key, value) => value == null || value == ''),
      'theme': <String, dynamic>{'color': themeColorHex},
    };
  }
}

/// `refund:status` — a refund request on one of the customer's orders was
/// raised / approved / rejected / cancelled. The `status` is authoritative
/// (PENDING | APPROVED | REJECTED | CANCELLED); clients reconcile with one
/// REST read.
class RefundStatusEvent {
  const RefundStatusEvent({
    required this.orderId,
    required this.refundRequestId,
    required this.status,
    this.event,
    this.amount,
    this.refundTo,
    this.seq,
    this.eventId,
  });

  final String orderId;
  final String refundRequestId;
  final String status;
  final String? event;
  final double? amount;

  /// 'WALLET' | 'RAZORPAY'
  final String? refundTo;
  final int? seq;
  final String? eventId;

  bool get isApproved => status == 'APPROVED';

  static RefundStatusEvent? tryParse(Map<String, dynamic> json) {
    final orderId = '${json['orderId'] ?? ''}'.trim();
    final requestId = '${json['refundRequestId'] ?? ''}'.trim();
    if (orderId.isEmpty || requestId.isEmpty) return null;
    final seq = json['seq'];
    final amount = json['amount'];
    return RefundStatusEvent(
      orderId: orderId,
      refundRequestId: requestId,
      status: '${json['status'] ?? 'PENDING'}'.toUpperCase(),
      event: json['event'] as String?,
      amount: amount is num ? amount.toDouble() : double.tryParse('$amount'),
      refundTo: json['refundTo'] as String?,
      seq: seq is num ? seq.toInt() : int.tryParse('$seq'),
      eventId: json['eventId'] as String?,
    );
  }
}

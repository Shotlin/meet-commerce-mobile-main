/// The latest refund request for one order — powers the order-detail
/// screen's status card (pending / approved / rejected / cancelled).
class RefundRequestStatusEntity {
  const RefundRequestStatusEntity({
    required this.id,
    required this.itemScope,
    required this.description,
    required this.status,
    required this.createdAt,
    this.adminNote,
    this.refundAmount,
    this.refundTo,
  });

  final String id;

  /// 'ALL' or 'SPECIFIC'.
  final String itemScope;
  final String description;

  /// 'PENDING', 'APPROVED', 'REJECTED', or 'CANCELLED'.
  final String status;
  final String? adminNote;
  final double? refundAmount;

  /// 'wallet' or 'original', set only once approved.
  final String? refundTo;
  final DateTime createdAt;

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
  bool get isCancelled => status == 'CANCELLED';

  /// Whether this request still blocks a fresh submission for the same
  /// order — only a cancelled request frees the order up again.
  bool get blocksNewRequest => !isCancelled;
}

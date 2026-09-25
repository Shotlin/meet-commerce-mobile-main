/// The vendor cleaning/packing video that actually backed one line item of
/// an order — resolved server-side from the exact inventory batch that
/// order line was fulfilled from (see backend `orders.service.js#getQualityVideos`).
/// `videoUrl` is null when this item has no traceable vendor batch (e.g. it
/// was stocked manually, outside vendor procurement) — never fabricated.
class OrderQualityVideoEntity {
  const OrderQualityVideoEntity({
    required this.orderItemId,
    required this.productName,
    this.videoUrl,
    this.vendorName,
    this.supplyNumber,
  });

  final String orderItemId;
  final String productName;
  final String? videoUrl;
  final String? vendorName;
  final String? supplyNumber;

  bool get hasVideo => videoUrl != null && videoUrl!.trim().isNotEmpty;
}

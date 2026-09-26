import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_quality_video_entity.dart';

/// The full response for "what does THIS order's invoice QR resolve to" —
/// carries the real order number alongside the per-item videos so the
/// screen that shows them can display, unambiguously, which order it
/// actually resolved (two different orders can legitimately show the same
/// vendor video when they were both fulfilled from the same real vendor
/// batch — this lets that be visually confirmed rather than looking like
/// the app might just be reusing stale/cached data).
class OrderQualityVideosResult {
  const OrderQualityVideosResult({required this.orderNumber, required this.items});

  final String? orderNumber;
  final List<OrderQualityVideoEntity> items;
}

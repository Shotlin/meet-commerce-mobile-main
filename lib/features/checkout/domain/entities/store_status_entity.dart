/// Whether the (single, global) storefront is currently open for ASAP
/// ordering. Mirrors the backend's `GET /api/v1/store/status` response
/// (bakaloo-backend migration 071/072) — priority is a manual admin
/// override, then the weekly hours schedule, then fail-open by default.
class StoreStatusEntity {
  const StoreStatusEntity({
    required this.isOpen,
    required this.source,
    this.reason,
    this.next7Days = const [],
    this.closedBannerImageUrl,
  });

  final bool isOpen;
  final String source; // 'MANUAL_OVERRIDE' | 'WEEKLY_SCHEDULE' | 'DEFAULT'
  final String? reason;
  final List<StoreDayAvailability> next7Days;
  /// Admin-uploaded "we are closed" banner (Store Hours settings) shown at
  /// the top of the home screen while [isOpen] is false. Null when the
  /// admin has never uploaded one.
  final String? closedBannerImageUrl;

  factory StoreStatusEntity.fromJson(Map<String, dynamic> json) {
    final rawDays = json['next7Days'] as List<dynamic>?;
    return StoreStatusEntity(
      isOpen: json['isOpen'] as bool? ?? true,
      source: json['source'] as String? ?? 'DEFAULT',
      reason: json['reason'] as String?,
      next7Days: rawDays == null
          ? const []
          : rawDays
              .map((d) => StoreDayAvailability.fromJson(d as Map<String, dynamic>))
              .toList(),
      closedBannerImageUrl: json['closedBannerImageUrl'] as String?,
    );
  }

  /// Fail-open default used while the status hasn't loaded yet — never
  /// blocks ASAP ordering just because the network call is still in
  /// flight, same fail-open principle the backend evaluator uses.
  factory StoreStatusEntity.open() =>
      const StoreStatusEntity(isOpen: true, source: 'DEFAULT');
}

/// One day's entry in the "view store hours" surface — the next 7 days'
/// open/closed status and hours, sourced from the weekly schedule (only
/// today's entry reflects a live manual override).
class StoreDayAvailability {
  const StoreDayAvailability({
    required this.date,
    required this.weekday,
    required this.isOpen,
    this.open,
    this.close,
    this.reason,
  });

  final String date; // 'YYYY-MM-DD'
  final String weekday; // 'monday'..'sunday'
  final bool isOpen;
  final String? open; // 'HH:MM'
  final String? close; // 'HH:MM'
  final String? reason;

  factory StoreDayAvailability.fromJson(Map<String, dynamic> json) {
    return StoreDayAvailability(
      date: json['date'] as String? ?? '',
      weekday: json['weekday'] as String? ?? '',
      isOpen: json['isOpen'] as bool? ?? true,
      open: json['open'] as String?,
      close: json['close'] as String?,
      reason: json['reason'] as String?,
    );
  }
}

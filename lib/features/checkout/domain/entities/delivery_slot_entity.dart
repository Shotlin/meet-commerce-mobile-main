/// Represents a single deliverable time slot.
class DeliverySlotEntity {
  const DeliverySlotEntity({
    required this.id,
    required this.label,
    required this.start,
    required this.end,
    required this.available,
    this.reason,
  });

  final String id;
  final String label;
  final DateTime start;
  final DateTime end;
  final bool available;
  final String? reason;

  factory DeliverySlotEntity.fromJson(Map<String, dynamic> json) {
    return DeliverySlotEntity(
      id: json['id'] as String,
      label: json['label'] as String,
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      available: json['available'] as bool? ?? false,
      reason: json['reason'] as String?,
    );
  }
}

/// Represents one day's worth of delivery slots.
class DeliverySlotDayEntity {
  const DeliverySlotDayEntity({
    required this.date,
    required this.label,
    required this.slots,
  });

  final String date;
  final String label;
  final List<DeliverySlotEntity> slots;

  factory DeliverySlotDayEntity.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['slots'] as List<dynamic>? ?? [];
    return DeliverySlotDayEntity(
      date: json['date'] as String,
      label: json['label'] as String,
      slots: rawSlots
          .map((s) => DeliverySlotEntity.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
    );
  }
}

/// The user's selected delivery preference — either ASAP or a specific slot.
class SelectedDeliverySlot {
  const SelectedDeliverySlot.asap({this.quickDeliverySelected = false})
      : mode = 'ASAP',
        slot = null,
        dayLabel = null;

  const SelectedDeliverySlot.scheduled({
    required DeliverySlotEntity this.slot,
    required String this.dayLabel,
  })  : mode = 'SCHEDULED',
        quickDeliverySelected = false;

  final String mode;
  final DeliverySlotEntity? slot;
  final String? dayLabel;
  /// Whether the customer explicitly opted into the paid "Quick Delivery"
  /// upgrade — only meaningful when [isAsap] is true. Never implied by
  /// picking ASAP alone; the admin-configured surcharge (if enabled) is
  /// only charged when this is explicitly true.
  final bool quickDeliverySelected;

  bool get isAsap => mode == 'ASAP';
  bool get isScheduled => mode == 'SCHEDULED';

  /// Short display label for the cart row / checkout card. [etaMinutes]
  /// should come from the real backend-configured delivery estimate
  /// (`BillSummaryEntity.deliveryEstimate.minutes`) — this entity has no
  /// access to that value itself, so it must be passed in rather than
  /// hardcoded, unlike the previous fixed "6 mins" placeholder.
  String displayLabel(int etaMinutes) {
    if (isAsap) return 'Delivering in $etaMinutes mins';
    return '$dayLabel, ${slot!.label}';
  }

  /// Full label stored on the order (e.g. "Today, 7:00 PM – 9:00 PM")
  String get slotLabel => isAsap ? '' : '$dayLabel, ${slot!.label}';
}

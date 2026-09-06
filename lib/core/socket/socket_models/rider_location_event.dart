class RiderLocationEvent {
  const RiderLocationEvent({
    required this.orderId,
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speed,
    this.timestamp,
  });

  final String orderId;
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speed;
  final DateTime? timestamp;

  factory RiderLocationEvent.fromJson(Map<String, dynamic> json) {
    return RiderLocationEvent(
      orderId: _readString(
        json,
        <String>['orderId', 'order_id', 'id'],
      ),
      latitude: _readDouble(
        json,
        <String>['latitude', 'lat'],
      ),
      longitude: _readDouble(
        json,
        <String>['longitude', 'lng', 'lon'],
      ),
      heading: _readNullableDouble(
        json,
        <String>['heading', 'bearing', 'rotation'],
      ),
      speed: _readNullableDouble(json, <String>['speed']),
      timestamp: _readDateTime(
        json,
        <String>['timestamp', 'updatedAt', 'updated_at'],
      ),
    );
  }

  static String _readString(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return fallback;
  }

  static double _readDouble(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String && value.trim().isNotEmpty) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return 0;
  }

  static double? _readNullableDouble(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String && value.trim().isNotEmpty) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  static DateTime? _readDateTime(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
      if (value is int) {
        final milliseconds = value > 9999999999 ? value : value * 1000;
        return DateTime.fromMillisecondsSinceEpoch(milliseconds);
      }
    }
    return null;
  }
}

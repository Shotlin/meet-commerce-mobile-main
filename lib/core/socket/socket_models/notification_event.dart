class NotificationEvent {
  const NotificationEvent({
    required this.type,
    required this.title,
    required this.body,
    this.data = const <String, dynamic>{},
    this.timestamp,
  });

  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime? timestamp;

  factory NotificationEvent.fromJson(Map<String, dynamic> json) {
    return NotificationEvent(
      type: _readString(
        json,
        <String>['type', 'eventType'],
        fallback: 'general',
      ),
      title: _readString(
        json,
        <String>['title'],
        fallback: 'Bakaloo',
      ),
      body: _readString(
        json,
        <String>['body', 'message'],
      ),
      data: _readMap(json, <String>['data', 'payload']),
      timestamp: _readDateTime(
        json,
        <String>['timestamp', 'createdAt', 'created_at'],
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

  static Map<String, dynamic> _readMap(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
    }
    return const <String, dynamic>{};
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

import 'package:bakaloo_flutter_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:bakaloo_flutter_app/features/notifications/domain/entities/notification_preference_entity.dart';
import 'package:bakaloo_flutter_app/shared/entities/pagination_entity.dart';

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.readAt,
    this.imageUrl,
    this.deepLink,
    this.data = const <String, dynamic>{},
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;
  final String? imageUrl;
  final String? deepLink;
  final Map<String, dynamic> data;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final createdAt = _readDateTime(
          json,
          const <String>['createdAt', 'created_at', 'timestamp'],
        ) ??
        DateTime.now();

    return NotificationModel(
      id: _readString(json, const <String>['id', 'notificationId']),
      type: _readString(
        json,
        const <String>['type', 'notificationType'],
        fallback: 'SYSTEM',
      ),
      title: _readString(
        json,
        const <String>['title'],
        fallback: 'Bakaloo',
      ),
      body: _readString(
        json,
        const <String>['body', 'message'],
      ),
      createdAt: createdAt,
      isRead: _readBool(json, const <String>['isRead', 'is_read']),
      readAt: _readDateTime(
        json,
        const <String>['readAt', 'read_at'],
      ),
      imageUrl: _readStringOrNull(json, const ['image_url', 'imageUrl']),
      deepLink: _readStringOrNull(json, const ['deep_link', 'deepLink']),
      data: _readMap(json, const <String>['data', 'payload']),
    );
  }

  NotificationEntity toEntity() {
    return NotificationEntity(
      id: id,
      type: type,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: isRead,
      readAt: readAt,
      imageUrl: _readStringOrNull(data, const ['imageUrl', 'image_url']),
      deepLink: _readStringOrNull(data, const ['deepLink', 'deep_link']),
      data: data,
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

  static String? _readStringOrNull(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
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
      } else if (value is int) {
        final milliseconds = value > 9999999999 ? value : value * 1000;
        return DateTime.fromMillisecondsSinceEpoch(milliseconds);
      }
    }
    return null;
  }

  static bool _readBool(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      if (value is String && value.trim().isNotEmpty) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') {
          return true;
        }
        if (normalized == 'false' || normalized == '0') {
          return false;
        }
      }
    }
    return false;
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
}

class NotificationsPageModel {
  const NotificationsPageModel({
    required this.items,
    required this.pagination,
    required this.unreadCount,
  });

  final List<NotificationModel> items;
  final PaginationEntity pagination;
  final int unreadCount;

  factory NotificationsPageModel.fromPayload(
    Map<String, dynamic> payload, {
    required int page,
    required int limit,
  }) {
    final data = payload['data'];
    if (data is! Map) {
      return NotificationsPageModel(
        items: const <NotificationModel>[],
        pagination: PaginationEntity(
          page: page,
          limit: limit,
          total: 0,
          totalPages: 0,
        ),
        unreadCount: 0,
      );
    }

    final map = Map<String, dynamic>.from(data);
    final notificationsRaw = map['notifications'];
    final items = notificationsRaw is List
        ? notificationsRaw
            .whereType<Map>()
            .map(
              (raw) => NotificationModel.fromJson(
                Map<String, dynamic>.from(raw),
              ),
            )
            .toList(growable: false)
        : const <NotificationModel>[];

    final paginationRaw = map['pagination'];
    final pagination = paginationRaw is Map
        ? PaginationEntity.fromJson(Map<String, dynamic>.from(paginationRaw))
        : PaginationEntity(
            page: page,
            limit: limit,
            total: items.length,
            totalPages: items.isEmpty ? 0 : 1,
          );

    return NotificationsPageModel(
      items: items,
      pagination: pagination,
      unreadCount: _readInt(map['unreadCount']) ?? _readInt(map['unread']) ?? 0,
    );
  }

  static int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String && value.trim().isNotEmpty) {
      return int.tryParse(value.trim());
    }
    return null;
  }
}

class NotificationPreferenceModel {
  const NotificationPreferenceModel({
    this.orderUpdates = true,
    this.promotions = true,
    this.newProducts = true,
    this.priceDrops = true,
    this.deliveryUpdates = true,
  });

  final bool orderUpdates;
  final bool promotions;
  final bool newProducts;
  final bool priceDrops;
  final bool deliveryUpdates;

  factory NotificationPreferenceModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferenceModel(
      orderUpdates: _readBool(json['orderUpdates'], true),
      promotions: _readBool(json['promotions'], true),
      newProducts: _readBool(json['newProducts'], true),
      priceDrops: _readBool(json['priceDrops'], true),
      deliveryUpdates: _readBool(json['deliveryUpdates'], true),
    );
  }

  NotificationPreferenceEntity toEntity() {
    return NotificationPreferenceEntity(
      orderUpdates: orderUpdates,
      promotions: promotions,
      newProducts: newProducts,
      priceDrops: priceDrops,
      deliveryUpdates: deliveryUpdates,
    );
  }

  static NotificationPreferenceModel fromEntity(
    NotificationPreferenceEntity entity,
  ) {
    return NotificationPreferenceModel(
      orderUpdates: entity.orderUpdates,
      promotions: entity.promotions,
      newProducts: entity.newProducts,
      priceDrops: entity.priceDrops,
      deliveryUpdates: entity.deliveryUpdates,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'orderUpdates': orderUpdates,
      'promotions': promotions,
      'newProducts': newProducts,
      'priceDrops': priceDrops,
      'deliveryUpdates': deliveryUpdates,
    };
  }

  static bool _readBool(Object? value, bool fallback) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String && value.trim().isNotEmpty) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
    return fallback;
  }
}

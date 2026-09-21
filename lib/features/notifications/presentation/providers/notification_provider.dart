import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/core/notifications/fcm_token_helper.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_models/notification_event.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_service.dart';
import 'package:bakaloo_flutter_app/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:bakaloo_flutter_app/features/notifications/domain/entities/notification_preference_entity.dart';
import 'package:bakaloo_flutter_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:bakaloo_flutter_app/features/notifications/domain/usecases/delete_notification_usecase.dart';
import 'package:bakaloo_flutter_app/features/notifications/domain/usecases/get_notifications_usecase.dart';
import 'package:bakaloo_flutter_app/features/notifications/domain/usecases/get_preferences_usecase.dart';
import 'package:bakaloo_flutter_app/features/notifications/domain/usecases/mark_all_read_usecase.dart';
import 'package:bakaloo_flutter_app/features/notifications/domain/usecases/mark_campaign_opened_usecase.dart';
import 'package:bakaloo_flutter_app/features/notifications/domain/usecases/mark_read_usecase.dart';
import 'package:bakaloo_flutter_app/features/notifications/domain/usecases/register_fcm_token_usecase.dart';
import 'package:bakaloo_flutter_app/features/notifications/domain/usecases/update_preferences_usecase.dart';
import 'package:bakaloo_flutter_app/shared/entities/pagination_entity.dart';

part 'notification_provider.g.dart';

class NotificationsState {
  const NotificationsState({
    required this.items,
    required this.page,
    required this.hasMore,
    required this.unreadCount,
    required this.isLoadingMore,
  });

  final List<NotificationEntity> items;
  final int page;
  final bool hasMore;
  final int unreadCount;
  final bool isLoadingMore;

  NotificationsState copyWith({
    List<NotificationEntity>? items,
    int? page,
    bool? hasMore,
    int? unreadCount,
    bool? isLoadingMore,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  static const empty = NotificationsState(
    items: <NotificationEntity>[],
    page: 1,
    hasMore: false,
    unreadCount: 0,
    isLoadingMore: false,
  );
}

class NotificationActionResult {
  const NotificationActionResult({this.failure});

  final Failure? failure;

  bool get isSuccess => failure == null;
}

final notificationRemoteDataSourceProvider =
    Provider<NotificationRemoteDataSource>((Ref ref) {
  return NotificationRemoteDataSource(ref.watch(apiClientProvider));
});

final notificationRepositoryProvider = Provider<NotificationRepository>((
  Ref ref,
) {
  return NotificationRepositoryImpl(
    remoteDataSource: ref.watch(notificationRemoteDataSourceProvider),
  );
});

final getNotificationsUseCaseProvider = Provider<GetNotificationsUseCase>((
  Ref ref,
) {
  return GetNotificationsUseCase(ref.watch(notificationRepositoryProvider));
});

final markReadUseCaseProvider = Provider<MarkReadUseCase>((Ref ref) {
  return MarkReadUseCase(ref.watch(notificationRepositoryProvider));
});

final markAllReadUseCaseProvider = Provider<MarkAllReadUseCase>((Ref ref) {
  return MarkAllReadUseCase(ref.watch(notificationRepositoryProvider));
});

final deleteNotificationUseCaseProvider =
    Provider<DeleteNotificationUseCase>((Ref ref) {
  return DeleteNotificationUseCase(ref.watch(notificationRepositoryProvider));
});

final getPreferencesUseCaseProvider = Provider<GetPreferencesUseCase>((
  Ref ref,
) {
  return GetPreferencesUseCase(ref.watch(notificationRepositoryProvider));
});

final markCampaignOpenedUseCaseProvider =
    Provider<MarkCampaignOpenedUseCase>((Ref ref) {
  return MarkCampaignOpenedUseCase(ref.watch(notificationRepositoryProvider));
});

final registerFcmTokenUseCaseProvider = Provider<RegisterFcmTokenUseCase>((
  Ref ref,
) {
  return RegisterFcmTokenUseCase(ref.watch(notificationRepositoryProvider));
});

final updatePreferencesUseCaseProvider = Provider<UpdatePreferencesUseCase>((
  Ref ref,
) {
  return UpdatePreferencesUseCase(ref.watch(notificationRepositoryProvider));
});

@riverpod
Stream<NotificationEvent> socketNotificationStream(Ref ref) {
  return ref.watch(socketServiceProvider).notificationStream;
}

@Riverpod(keepAlive: true)
class NotificationNotifier extends _$NotificationNotifier {
  static const _pageSize = 20;

  @override
  Future<NotificationsState> build() async {
    return _loadFirstPage();
  }

  Future<void> refresh() async {
    final previous = _currentState ?? NotificationsState.empty;
    state = const AsyncLoading();
    final refreshed = await _loadFirstPage();
    state = AsyncData(
      refreshed.copyWith(
        items: _mergeSocketInjected(previous.items, refreshed.items),
      ),
    );
  }

  Future<void> loadMore() async {
    final current = _currentState;
    if (current == null || !current.hasMore || current.isLoadingMore) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));
    final nextPage = current.page + 1;
    final result = await ref.read(getNotificationsUseCaseProvider).call(
          page: nextPage,
          limit: _pageSize,
        );

    result.fold(
      (failure) {
        state = AsyncData(current.copyWith(isLoadingMore: false));
      },
      (data) {
        state = AsyncData(
          current.copyWith(
            items: <NotificationEntity>[
              ...current.items,
              ...data.items,
            ],
            page: data.pagination.page,
            hasMore: _hasMore(data.pagination),
            unreadCount: data.unreadCount,
            isLoadingMore: false,
          ),
        );
      },
    );
  }

  Future<NotificationActionResult> markRead(String notificationId) async {
    final current = _currentState;
    if (current == null) {
      return const NotificationActionResult();
    }

    final previous = current;
    final updatedItems = current.items
        .map(
          (item) => item.id == notificationId
              ? item.copyWith(
                  isRead: true,
                  readAt: item.readAt ?? DateTime.now(),
                )
              : item,
        )
        .toList(growable: false);
    final unread = updatedItems.where((item) => item.isUnread).length;
    state = AsyncData(
      current.copyWith(
        items: updatedItems,
        unreadCount: unread,
      ),
    );

    final result = await ref.read(markReadUseCaseProvider).call(notificationId);
    return result.fold(
      (failure) {
        state = AsyncData(previous);
        return NotificationActionResult(failure: failure);
      },
      (_) => const NotificationActionResult(),
    );
  }

  Future<NotificationActionResult> markAllRead() async {
    final current = _currentState;
    if (current == null) {
      return const NotificationActionResult();
    }

    final previous = current;
    final now = DateTime.now();
    state = AsyncData(
      current.copyWith(
        items: current.items
            .map(
              (item) => item.copyWith(
                isRead: true,
                readAt: item.readAt ?? now,
              ),
            )
            .toList(growable: false),
        unreadCount: 0,
      ),
    );

    final result = await ref.read(markAllReadUseCaseProvider).call();
    return result.fold(
      (failure) {
        state = AsyncData(previous);
        return NotificationActionResult(failure: failure);
      },
      (_) => const NotificationActionResult(),
    );
  }

  Future<NotificationActionResult> deleteNotification(
    String notificationId,
  ) async {
    final current = _currentState;
    if (current == null) {
      return const NotificationActionResult();
    }

    final previous = current;
    final updatedItems = current.items
        .where((item) => item.id != notificationId)
        .toList(growable: false);

    state = AsyncData(
      current.copyWith(
        items: updatedItems,
        unreadCount: updatedItems.where((item) => item.isUnread).length,
      ),
    );

    final result =
        await ref.read(deleteNotificationUseCaseProvider).call(notificationId);
    return result.fold(
      (failure) {
        state = AsyncData(previous);
        return NotificationActionResult(failure: failure);
      },
      (_) => const NotificationActionResult(),
    );
  }

  void addSocketNotification(NotificationEvent event) {
    final current = _currentState ?? NotificationsState.empty;
    final id = _readSocketNotificationId(event);
    if (id == null || id.isEmpty) {
      return;
    }

    final alreadyExists = current.items.any((item) => item.id == id);
    if (alreadyExists) {
      return;
    }

    final createdAt = event.timestamp ?? DateTime.now();
    final incoming = NotificationEntity(
      id: id,
      type: event.type,
      title: event.title,
      body: event.body,
      createdAt: createdAt,
      data: event.data,
      isRead: false,
    );

    state = AsyncData(
      current.copyWith(
        items: <NotificationEntity>[incoming, ...current.items],
        unreadCount: current.unreadCount + 1,
      ),
    );
  }

  Future<NotificationActionResult> registerCurrentFcmToken() async {
    final token = await getFcmTokenAwaitingApns(FirebaseMessaging.instance);
    if (token == null || token.trim().isEmpty) {
      return const NotificationActionResult();
    }

    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      TargetPlatform.macOS => 'ios',
      TargetPlatform.windows => 'android',
      TargetPlatform.linux => 'android',
      TargetPlatform.fuchsia => 'android',
    };

    final result = await ref.read(registerFcmTokenUseCaseProvider).call(
          token: token.trim(),
          platform: platform,
        );
    return result.fold(
      (failure) => NotificationActionResult(failure: failure),
      (_) => const NotificationActionResult(),
    );
  }

  Future<NotificationsState> _loadFirstPage() async {
    final result = await ref.read(getNotificationsUseCaseProvider).call(
          page: 1,
          limit: _pageSize,
        );

    return result.fold(
      (failure) => throw StateError(failure.message),
      (data) => NotificationsState(
        items: data.items,
        page: data.pagination.page,
        hasMore: _hasMore(data.pagination),
        unreadCount: data.unreadCount,
        isLoadingMore: false,
      ),
    );
  }

  bool _hasMore(PaginationEntity pagination) {
    if (pagination.totalPages <= 0) {
      return false;
    }
    return pagination.page < pagination.totalPages;
  }

  List<NotificationEntity> _mergeSocketInjected(
    List<NotificationEntity> previous,
    List<NotificationEntity> fresh,
  ) {
    if (previous.isEmpty) {
      return fresh;
    }

    final existingIds = fresh.map((item) => item.id).toSet();
    final injected = previous
        .where((item) => item.id.isNotEmpty && !existingIds.contains(item.id))
        .toList(growable: false);
    return <NotificationEntity>[...injected, ...fresh];
  }

  String? _readSocketNotificationId(NotificationEvent event) {
    final fromData = event.data['notificationId'];
    if (fromData is String && fromData.trim().isNotEmpty) {
      return fromData.trim();
    }
    final fallback = event.data['id'];
    if (fallback is String && fallback.trim().isNotEmpty) {
      return fallback.trim();
    }
    return null;
  }

  NotificationsState? get _currentState => switch (state) {
        AsyncData(:final value) => value,
        _ => null,
      };
}

@Riverpod(keepAlive: true)
class NotificationPreferences extends _$NotificationPreferences {
  @override
  Future<NotificationPreferenceEntity> build() async {
    final result = await ref.read(getPreferencesUseCaseProvider).call();
    return result.fold(
      (failure) => throw StateError(failure.message),
      (preferences) => preferences,
    );
  }

  Future<NotificationActionResult> updatePreferences(
    NotificationPreferenceEntity preferences,
  ) async {
    final previous = _currentPreferences;
    state = AsyncData(preferences);
    final result = await ref.read(updatePreferencesUseCaseProvider).call(
          preferences,
        );
    return result.fold(
      (failure) {
        if (previous != null) {
          state = AsyncData(previous);
        } else {
          state = AsyncError(failure, StackTrace.current);
        }
        return NotificationActionResult(failure: failure);
      },
      (updated) {
        state = AsyncData(updated);
        return const NotificationActionResult();
      },
    );
  }

  NotificationPreferenceEntity? get _currentPreferences => switch (state) {
        AsyncData(:final value) => value,
        _ => null,
      };
}

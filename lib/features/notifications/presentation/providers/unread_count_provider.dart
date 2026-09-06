import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/features/notifications/presentation/providers/notification_provider.dart';

part 'unread_count_provider.g.dart';

@Riverpod(keepAlive: true)
int unreadCount(Ref ref) {
  final state = ref.watch(notificationProvider);
  return switch (state) {
    AsyncData(:final value) => value.unreadCount,
    _ => 0,
  };
}

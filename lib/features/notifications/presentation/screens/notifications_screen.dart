import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:bakaloo_flutter_app/core/notifications/notification_router.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:bakaloo_flutter_app/features/notifications/presentation/providers/notification_provider.dart';
import 'package:bakaloo_flutter_app/features/notifications/presentation/providers/unread_count_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _knownIds = <String>{};
  final Set<String> _animatedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(notificationProvider, (previous, next) {
      final previousValue = switch (previous) {
        AsyncData<NotificationsState>(:final value) => value,
        _ => null,
      };
      final nextValue = switch (next) {
        AsyncData<NotificationsState>(:final value) => value,
        _ => null,
      };

      final previousIds =
          previousValue?.items.map((item) => item.id).toSet() ?? _knownIds;
      final currentItems = nextValue?.items ?? const <NotificationEntity>[];

      for (final item in currentItems) {
        if (!previousIds.contains(item.id)) {
          _animatedIds.add(item.id);
          Future<void>.delayed(const Duration(milliseconds: 320), () {
            if (!mounted) {
              return;
            }
            setState(() {
              _animatedIds.remove(item.id);
            });
          });
        }
      }
      _knownIds
        ..clear()
        ..addAll(currentItems.map((item) => item.id));
    });

    final notificationsAsync = ref.watch(notificationProvider);
    final unreadCount = ref.watch(unreadCountProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text('Notifications', style: AppTextStyles.h2),
        actions: <Widget>[
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                'Mark all read',
                style: AppTextStyles.buttonSmall.copyWith(
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
        error: (error, stackTrace) => _buildErrorState(error),
        data: (state) {
          if (state.items.isEmpty) {
            return _buildEmptyState();
          }

          final grouped = _groupNotifications(state.items);
          return RefreshIndicator(
            color: AppColors.primaryGreen,
            onRefresh: () => ref.read(notificationProvider.notifier).refresh(),
            child: ListView.separated(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 20.h),
              itemBuilder: (context, index) {
                if (index >= grouped.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  );
                }

                final section = grouped[index];
                return _buildGroup(section.label, section.items);
              },
              separatorBuilder: (_, __) => Gap(10.h),
              itemCount: grouped.length + (state.isLoadingMore ? 1 : 0),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    final message = error.toString().replaceFirst('Bad state: ', '');
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            Gap(14.h),
            FilledButton(
              onPressed: () =>
                  ref.read(notificationProvider.notifier).refresh(),
              child: Text(
                'Retry',
                style: AppTextStyles.buttonMedium.copyWith(
                  color: AppColors.textOnGreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: 160.h,
              width: 160.w,
              child: FutureBuilder<String>(
                future: rootBundle.loadString(
                  'assets/animations/sleeping_bell.json',
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.hasData) {
                    return Lottie.asset('assets/animations/sleeping_bell.json');
                  }
                  return Center(
                    child: PhosphorIcon(
                      PhosphorIcons.bellZ,
                      size: 72.sp,
                      color: AppColors.textDisabled,
                    ),
                  );
                },
              ),
            ),
            Gap(8.h),
            Text('No notifications yet', style: AppTextStyles.h3),
          ],
        ),
      ),
    );
  }

  Widget _buildGroup(String label, List<NotificationEntity> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 6.h),
          child: Text(
            label,
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg.r),
          ),
          child: Column(
            children: items.map((item) {
              final tile = _NotificationTile(
                item: item,
                onTap: () => _onTapNotification(item),
                onMarkRead: () => _markRead(item.id),
                onDelete: () => _delete(item.id),
              );
              if (_animatedIds.contains(item.id)) {
                return tile
                    .animate()
                    .slideY(
                      begin: -0.3,
                      end: 0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                    )
                    .fadeIn(duration: const Duration(milliseconds: 200));
              }
              return tile;
            }).toList(growable: false),
          ),
        ),
      ],
    );
  }

  List<_NotificationGroup> _groupNotifications(
    List<NotificationEntity> notifications,
  ) {
    final today = <NotificationEntity>[];
    final yesterday = <NotificationEntity>[];
    final earlier = <NotificationEntity>[];

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfYesterday = startOfToday.subtract(const Duration(days: 1));
    for (final notification in notifications) {
      final created = notification.createdAt.toLocal();
      if (!created.isBefore(startOfToday)) {
        today.add(notification);
      } else if (!created.isBefore(startOfYesterday)) {
        yesterday.add(notification);
      } else {
        earlier.add(notification);
      }
    }

    final groups = <_NotificationGroup>[];
    if (today.isNotEmpty) {
      groups.add(_NotificationGroup(label: 'Today', items: today));
    }
    if (yesterday.isNotEmpty) {
      groups.add(_NotificationGroup(label: 'Yesterday', items: yesterday));
    }
    if (earlier.isNotEmpty) {
      groups
          .add(_NotificationGroup(label: 'Earlier this week', items: earlier));
    }
    return groups;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final threshold = _scrollController.position.maxScrollExtent - 220.h;
    if (_scrollController.position.pixels >= threshold) {
      unawaited(ref.read(notificationProvider.notifier).loadMore());
    }
  }

  Future<void> _markRead(String id) async {
    final result = await ref.read(notificationProvider.notifier).markRead(id);
    if (!mounted || result.isSuccess || result.failure == null) {
      return;
    }
    AppToast.show(context, result.failure!.message);
  }

  Future<void> _markAllRead() async {
    final result = await ref.read(notificationProvider.notifier).markAllRead();
    if (!mounted || result.isSuccess || result.failure == null) {
      return;
    }
    AppToast.show(context, result.failure!.message);
  }

  Future<void> _delete(String id) async {
    final result =
        await ref.read(notificationProvider.notifier).deleteNotification(id);
    if (!mounted || result.isSuccess || result.failure == null) {
      return;
    }
    AppToast.show(context, result.failure!.message);
  }

  Future<void> _onTapNotification(NotificationEntity item) async {
    if (item.isUnread) {
      await _markRead(item.id);
    }
    if (!mounted) {
      return;
    }

    final path = NotificationRouter.getPath(
      <String, dynamic>{
        ...item.data,
        'type': item.type,
      },
    );
    if (path != null && path.isNotEmpty) {
      context.go(path);
    }
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
    required this.onMarkRead,
    required this.onDelete,
  });

  final NotificationEntity item;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bg = item.isUnread
        ? AppColors.primaryGreenLight.withValues(alpha: 0.35)
        : AppColors.bgCard;

    return Slidable(
      key: ValueKey(item.id),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.24,
        children: <Widget>[
          SlidableAction(
            onPressed: (_) => onMarkRead(),
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            icon: PhosphorIcons.checkCircle,
            label: 'Read',
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.24,
        children: <Widget>[
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: AppColors.errorRed,
            foregroundColor: Colors.white,
            icon: PhosphorIcons.trash,
            label: 'Delete',
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(color: bg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 3.w,
                  height: 78.h,
                  decoration: BoxDecoration(
                    color: item.isUnread
                        ? AppColors.primaryGreen
                        : Colors.transparent,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10.r),
                      bottomLeft: Radius.circular(10.r),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 34.r,
                          height: 34.r,
                          decoration: const BoxDecoration(
                            color: AppColors.bgInput,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: PhosphorIcon(
                              _iconForType(item.type),
                              size: 18.sp,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ),
                        Gap(10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.sp,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Gap(3.h),
                              Text(
                                item.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontSize: 13.sp,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Gap(4.h),
                              Text(
                                timeago.format(item.createdAt),
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontSize: 11.sp,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (item.isUnread)
                          Container(
                            width: 8.r,
                            height: 8.r,
                            margin: EdgeInsets.only(top: 5.h),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    final normalized = type.trim().toUpperCase();
    switch (normalized) {
      case 'ORDER_STATUS':
        return PhosphorIcons.package;
      case 'PAYMENT':
        return PhosphorIcons.checkCircle;
      case 'PROMOTION':
        return PhosphorIcons.ticket;
      case 'DELIVERY':
        return PhosphorIcons.motorcycle;
      default:
        return PhosphorIcons.bell;
    }
  }
}

class _NotificationGroup {
  const _NotificationGroup({
    required this.label,
    required this.items,
  });

  final String label;
  final List<NotificationEntity> items;
}

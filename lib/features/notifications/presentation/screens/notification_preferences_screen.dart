import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/notifications/domain/entities/notification_preference_entity.dart';
import 'package:bakaloo_flutter_app/features/notifications/presentation/providers/notification_provider.dart';

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text('Notification Preferences', style: AppTextStyles.h2),
      ),
      body: prefsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryGreen,
          ),
        ),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Text(
              error.toString().replaceFirst('Bad state: ', ''),
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (preferences) => ListView(
          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 24.h),
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg.r),
                boxShadow: const <BoxShadow>[AppShadows.cardShadow],
              ),
              child: Column(
                children: <Widget>[
                  _PreferenceTile(
                    icon: PhosphorIcons.package,
                    title: 'Order Updates',
                    value: preferences.orderUpdates,
                    onChanged: (value) => _updatePreferences(
                      context,
                      ref,
                      preferences.copyWith(orderUpdates: value),
                    ),
                  ),
                  _divider(),
                  _PreferenceTile(
                    icon: PhosphorIcons.ticket,
                    title: 'Promotions',
                    value: preferences.promotions,
                    onChanged: (value) => _updatePreferences(
                      context,
                      ref,
                      preferences.copyWith(promotions: value),
                    ),
                  ),
                  _divider(),
                  _PreferenceTile(
                    icon: PhosphorIcons.sparkle,
                    title: 'New Products',
                    value: preferences.newProducts,
                    onChanged: (value) => _updatePreferences(
                      context,
                      ref,
                      preferences.copyWith(newProducts: value),
                    ),
                  ),
                  _divider(),
                  _PreferenceTile(
                    icon: PhosphorIcons.tag,
                    title: 'Price Drops',
                    value: preferences.priceDrops,
                    onChanged: (value) => _updatePreferences(
                      context,
                      ref,
                      preferences.copyWith(priceDrops: value),
                    ),
                  ),
                ],
              ),
            ),
            Gap(14.h),
            Text(
              'System-level notification settings can still override these preferences.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1.h,
      thickness: 1.h,
      color: AppColors.divider,
    );
  }

  Future<void> _updatePreferences(
    BuildContext context,
    WidgetRef ref,
    NotificationPreferenceEntity next,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await ref
        .read(notificationPreferencesProvider.notifier)
        .updatePreferences(
          next,
        );
    if (result.isSuccess || result.failure == null) {
      return;
    }
    messenger?.showSnackBar(
      SnackBar(content: Text(result.failure!.message)),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      child: Row(
        children: <Widget>[
          PhosphorIcon(
            icon,
            size: 20.sp,
            color: AppColors.primaryGreen,
          ),
          Gap(12.w),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          CupertinoSwitch(
            activeTrackColor: AppColors.primaryGreen,
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

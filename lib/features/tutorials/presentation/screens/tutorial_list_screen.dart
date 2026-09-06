import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/tutorials/domain/entities/tutorial_video_entity.dart';
import 'package:bakaloo_flutter_app/features/tutorials/presentation/providers/tutorial_provider.dart';
import 'package:bakaloo_flutter_app/features/tutorials/presentation/screens/tutorial_player_screen.dart';

class TutorialListScreen extends ConsumerWidget {
  const TutorialListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tutorialsAsync = ref.watch(tutorialsProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: PhosphorIcon(
            PhosphorIcons.caretLeftBold,
            size: 20.sp,
            color: AppColors.textPrimary,
          ),
        ),
        title: Text('Tutorials', style: AppTextStyles.h2),
      ),
      body: tutorialsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
        error: (error, _) => _ErrorState(
          onRetry: () => ref.invalidate(tutorialsProvider),
        ),
        data: (List<TutorialVideoEntity> tutorials) {
          if (tutorials.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: EdgeInsets.all(16.w),
            itemCount: tutorials.length,
            separatorBuilder: (_, __) => Gap(12.h),
            itemBuilder: (BuildContext context, int index) {
              return _TutorialTile(tutorial: tutorials[index]);
            },
          );
        },
      ),
    );
  }
}

class _TutorialTile extends StatelessWidget {
  const _TutorialTile({required this.tutorial});

  final TutorialVideoEntity tutorial;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TutorialPlayerScreen(tutorial: tutorial),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(AppDimensions.radiusMd),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Image.network(
                    tutorial.thumbnailUrl,
                    width: 110.w,
                    height: 78.w,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 110.w,
                      height: 78.w,
                      color: AppColors.bgSection,
                      child: Icon(
                        Icons.videocam_off_outlined,
                        color: AppColors.textTertiary,
                        size: 20.sp,
                      ),
                    ),
                  ),
                  Container(
                    width: 28.w,
                    height: 28.w,
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 18.sp,
                    ),
                  ),
                ],
              ),
            ),
            Gap(12.w),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      tutorial.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (tutorial.language != null) ...<Widget>[
                      Gap(6.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bgSection,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusFull,
                          ),
                        ),
                        child: Text(
                          tutorial.language!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Gap(8.w),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PhosphorIcon(
              PhosphorIcons.videoCameraLight,
              size: 48.sp,
              color: AppColors.textTertiary,
            ),
            Gap(12.h),
            Text(
              'No tutorials available yet',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PhosphorIcon(
              PhosphorIcons.warningCircleLight,
              size: 48.sp,
              color: AppColors.errorRed,
            ),
            Gap(12.h),
            Text(
              'Unable to load tutorials right now.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Gap(16.h),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

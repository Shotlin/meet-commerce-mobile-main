import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/tutorials/domain/entities/tutorial_video_entity.dart';

/// Plays a tutorial's YouTube video embedded in-app (via the IFrame Player
/// API) — never redirects out to the YouTube app or a browser.
class TutorialPlayerScreen extends StatefulWidget {
  const TutorialPlayerScreen({required this.tutorial, super.key});

  final TutorialVideoEntity tutorial;

  @override
  State<TutorialPlayerScreen> createState() => _TutorialPlayerScreenState();
}

class _TutorialPlayerScreenState extends State<TutorialPlayerScreen> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.tutorial.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        mute: false,
        showControls: true,
        showFullscreenButton: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isShort = widget.tutorial.isShort;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
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
        title: Text(
          widget.tutorial.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.h3,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // The video surface itself keeps its own (dark, YouTube-style)
              // background while loading/playing — only the page chrome
              // around it needed to move off black.
              YoutubePlayer(
                controller: _controller,
                // A Short is filmed vertical (9:16) — forcing it into the
                // default 16:9 box is what made it render as a tiny
                // letterboxed sliver surrounded by black, both inline and
                // in fullscreen. A normal tutorial recording stays 16:9.
                aspectRatio: isShort ? 9 / 16 : 16 / 9,
                // Package defaults, kept explicit. With the aspect ratio
                // now correct for both shapes, rotating to landscape
                // fullscreen (or pillarboxing a Short if rotated) is
                // handled correctly by the underlying player.
                autoFullScreen: true,
                enableFullScreenOnVerticalDrag: true,
              ),
              Gap(16.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.tutorial.title,
                      style: AppTextStyles.h3,
                    ),
                    if (widget.tutorial.language != null) ...<Widget>[
                      Gap(6.h),
                      Text(
                        widget.tutorial.language!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Gap(24.h),
            ],
          ),
        ),
      ),
    );
  }
}

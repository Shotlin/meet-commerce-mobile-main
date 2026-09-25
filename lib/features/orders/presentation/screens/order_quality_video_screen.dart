import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:video_player/video_player.dart';

import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_quality_video_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_quality_videos_provider.dart';

/// What scanning a FreshCuts order QR resolves to — the vendor's real
/// cleaning/processing/packing video for the batch that supplied this
/// order, so the customer can see for themselves how it was handled.
/// Deliberately no rating flow here: watch, then Close, done.
class OrderQualityVideoScreen extends ConsumerWidget {
  const OrderQualityVideoScreen({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(orderQualityVideosProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quality Video'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: videosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => const _MessageState(
          icon: PhosphorIcons.warningCircle,
          message: "Couldn't load this order's quality video right now. Please try again.",
        ),
        data: (List<OrderQualityVideoEntity> items) {
          final withVideo = items.where((item) => item.hasVideo).toList(growable: false);
          if (withVideo.isEmpty) {
            return const _MessageState(
              icon: PhosphorIcons.filmSlate,
              message: 'No vendor quality video is available for this order yet.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: withVideo.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (BuildContext context, int index) {
              return _QualityVideoCard(item: withVideo[index]);
            },
          );
        },
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PhosphorIcon(icon, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

/// One vendor video, lazily initialized — the player is only created once
/// the customer taps "Watch Video", so scanning an order with several
/// items doesn't eagerly open several video streams at once.
class _QualityVideoCard extends StatefulWidget {
  const _QualityVideoCard({required this.item});

  final OrderQualityVideoEntity item;

  @override
  State<_QualityVideoCard> createState() => _QualityVideoCardState();
}

class _QualityVideoCardState extends State<_QualityVideoCard> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.item.videoUrl!));
      await controller.initialize();
      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
      );
      if (!mounted) {
        chewie.dispose();
        controller.dispose();
        return;
      }
      setState(() {
        _videoController = controller;
        _chewieController = chewie;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAECF0)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.item.productName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
          ),
          if (widget.item.vendorName != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              'Supplied by ${widget.item.vendorName}'
              '${widget.item.supplyNumber != null ? ' · ${widget.item.supplyNumber}' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 12),
          if (_chewieController != null)
            AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio == 0
                  ? 16 / 9
                  : _videoController!.value.aspectRatio,
              child: Chewie(controller: _chewieController!),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _play,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(PhosphorIcons.play, size: 18),
                label: Text(_hasError ? 'Try again' : 'Watch Video'),
              ),
            ),
        ],
      ),
    );
  }
}

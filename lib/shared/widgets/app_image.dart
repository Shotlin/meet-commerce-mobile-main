import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Scroll-aware image widget.
///
/// Defers network image decoding during fast scroll to prevent main-thread
/// frame spikes in horizontally and vertically scrolling product surfaces.
class AppImage extends StatefulWidget {
  const AppImage({
    required this.imageUrl,
    required this.memCacheWidth,
    required this.memCacheHeight,
    super.key,
    this.fit = BoxFit.cover,
    this.filterQuality = FilterQuality.high,
    this.alignment = Alignment.center,
    this.placeholder = const ColoredBox(
      color: Color(0xFFF5F5F5),
      child: SizedBox.expand(),
    ),
    this.errorWidget = const ColoredBox(
      color: Color(0xFFF5F5F5),
      child: SizedBox.expand(),
    ),
  });

  final String imageUrl;
  final int memCacheWidth;
  final int memCacheHeight;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final AlignmentGeometry alignment;
  final Widget placeholder;
  final Widget errorWidget;

  @override
  State<AppImage> createState() => _AppImageState();
}

class _AppImageState extends State<AppImage> {
  late final DisposableBuildContext<_AppImageState> _scrollAwareContext;

  @override
  void initState() {
    super.initState();
    _scrollAwareContext = DisposableBuildContext<_AppImageState>(this);
  }

  @override
  void dispose() {
    _scrollAwareContext.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = ScrollAwareImageProvider<CachedNetworkImageProvider>(
      context: _scrollAwareContext,
      imageProvider: CachedNetworkImageProvider(
        widget.imageUrl,
        maxWidth: widget.memCacheWidth,
        maxHeight: widget.memCacheHeight,
      ),
    );

    return Image(
      image: provider,
      fit: widget.fit,
      filterQuality: widget.filterQuality,
      alignment: widget.alignment,
      frameBuilder: (
        BuildContext context,
        Widget child,
        int? frame,
        bool wasSynchronouslyLoaded,
      ) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return widget.placeholder;
      },
      errorBuilder: (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) {
        return widget.errorWidget;
      },
    );
  }
}

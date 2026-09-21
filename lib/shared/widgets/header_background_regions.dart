import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';

/// Paints ONE horizontal slice of the tall "extended" header-background image
/// into a box that is exactly the height of that region.
///
/// The dashboard's "Extend into mini promotional bar" mode uploads a single
/// image whose top [topFraction] belongs to the header block (top bar + search
/// + category tabs) and whose remainder belongs to the mini promotional bar.
/// Each region draws its own slice:
///
/// * the image is sized so this region shows exactly its share of it — a
///   region of height `h` gets a virtual full-image height of `h / share` —
///   with the top slice anchored to the top edge and the promo slice anchored
///   to the bottom edge;
/// * [BoxFit.cover] inside that virtual box means a differently proportioned
///   upload is cropped, never stretched;
/// * the two slices meet at the seam because they come from the same source
///   split at the same fraction, so the artwork reads as one composition.
///
/// It needs bounded (typically tight) constraints — put it in
/// `Positioned.fill` or a sized box.
class HeaderBackgroundSlice extends StatelessWidget {
  const HeaderBackgroundSlice({
    required this.imageUrl,
    required this.topFraction,
    required this.showTop,
    @visibleForTesting this.debugImageBuilder,
    super.key,
  });

  final String imageUrl;

  /// A / (A + B) — see [HeaderBackgroundTheme.topFraction].
  final double topFraction;

  /// True: draw the top slice (header block). False: the bottom slice (promo bar).
  final bool showTop;

  /// Replaces the network image so layout can be tested without plugins.
  final Widget Function(String imageUrl, Alignment alignment)?
      debugImageBuilder;

  /// Share of the full image this region displays.
  double get _share => showTop ? topFraction : 1 - topFraction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (!width.isFinite || !height.isFinite || _share <= 0) {
          return const SizedBox.shrink();
        }

        final fullHeight = height / _share;
        final alignment =
            showTop ? Alignment.topCenter : Alignment.bottomCenter;
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

        return ClipRect(
          child: OverflowBox(
            alignment: alignment,
            minWidth: width,
            maxWidth: width,
            minHeight: fullHeight,
            maxHeight: fullHeight,
            child: debugImageBuilder?.call(imageUrl, alignment) ??
                AppImage(
                  imageUrl: imageUrl,
                  // Decode at (up to) the canonical 1080px export width; the
                  // height bound only has to be larger than the tall asset.
                  memCacheWidth: math
                      .min(
                        HeaderBackgroundTheme.defaultRecommendedWidth
                            .toDouble(),
                        width * devicePixelRatio,
                      )
                      .round(),
                  memCacheHeight: 4096,
                  fit: BoxFit.cover,
                  alignment: alignment,
                ),
          ),
        );
      },
    );
  }
}

/// The mini promotional bar directly below the category tabs. Its height is
/// the dashboard-measured promo region (B) scaled to this screen's width, and
/// it shows the bottom slice of the shared header-background image.
///
/// Renders nothing unless [HeaderBackgroundTheme.isExtended].
class HeaderPromoBar extends StatelessWidget {
  const HeaderPromoBar({
    required this.headerBackground,
    @visibleForTesting this.debugImageBuilder,
    super.key,
  });

  final HeaderBackgroundTheme headerBackground;

  /// See [HeaderBackgroundSlice.debugImageBuilder].
  final Widget Function(String imageUrl, Alignment alignment)?
      debugImageBuilder;

  @override
  Widget build(BuildContext context) {
    if (!headerBackground.isExtended) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return SizedBox(
          width: width,
          height: headerBackground.promoBarHeightFor(width),
          child: HeaderBackgroundSlice(
            imageUrl: headerBackground.imageUrl!,
            topFraction: headerBackground.topFraction,
            showTop: false,
            debugImageBuilder: debugImageBuilder,
          ),
        );
      },
    );
  }
}

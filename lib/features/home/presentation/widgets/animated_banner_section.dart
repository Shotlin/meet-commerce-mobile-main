import 'dart:convert';
import 'dart:typed_data';

// ignore: depend_on_referenced_packages
import 'package:archive/archive.dart';
import 'package:dotlottie_loader/dotlottie_loader.dart' show DotLottie;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_animation_loader.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/shared/utils/link_tap_handler.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';

class AnimatedBannerSection extends StatelessWidget {
  const AnimatedBannerSection({
    required this.assetPath,
    super.key,
    this.height = 120,
    this.bannerTheme,
    this.feeStripTheme,
    this.linkUrl,
  });

  final String assetPath;
  final double height;
  final BannerAnimationTheme? bannerTheme;
  final FeeStripTheme? feeStripTheme;
  final String? linkUrl;

  @override
  Widget build(BuildContext context) {
    final defaultBannerTheme = BannerAnimationTheme.defaults();
    final defaultFeeStripTheme = FeeStripTheme.defaults();
    final containerColor =
        bannerTheme?.containerColor ?? defaultBannerTheme.containerColor;
    final backgroundGradient = bannerTheme?.backgroundGradient ??
        defaultBannerTheme.backgroundGradient;
    final feeStripVisible =
        feeStripTheme?.visible ?? defaultFeeStripTheme.visible;
    final imageUrl = bannerTheme?.imageUrl;
    final lottieUrl = bannerTheme?.lottieUrl;
    final feeStripImageUrl = feeStripTheme?.imageUrl;
    final double feeStripHeight = 60.h;
    final double feeStripHorizontalInset = 5.w;
    final double feeStripImageYOffset = -2.h;

    return GestureDetector(
      onTap: linkUrl == null || linkUrl!.trim().isEmpty
          ? null
          : () => handleLinkTap(context, linkUrl!.trim()),
      child: RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: containerColor,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: double.infinity,
              height: height.h,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          backgroundGradient.first,
                          backgroundGradient.last,
                        ],
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Color(0x26FFFFFF),
                          Color(0x10FFFFFF),
                          Color(0x00FFFFFF),
                        ],
                        stops: <double>[0, 0.28, 0.62],
                      ),
                    ),
                  ),
                  _BannerAnimation(
                    assetPath: assetPath,
                    imageUrl: imageUrl,
                    lottieUrl: lottieUrl,
                  ),
                ],
              ),
            ),
            if (feeStripVisible) ...<Widget>[
              SizedBox(height: 4.h),
              SizedBox(
                width: double.infinity,
                height: feeStripHeight,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: feeStripHorizontalInset,
                  ),
                  child: ClipRect(
                    child: Transform.translate(
                      offset: Offset(0, feeStripImageYOffset),
                      child: feeStripImageUrl != null
                          ? AppImage(
                              imageUrl: feeStripImageUrl,
                              memCacheWidth: 1200,
                              memCacheHeight: 192,
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.high,
                              placeholder: const SizedBox.expand(),
                              errorWidget: const SizedBox.expand(),
                            )
                          : const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

class _BannerAnimation extends StatelessWidget {
  const _BannerAnimation({
    required this.assetPath,
    required this.imageUrl,
    required this.lottieUrl,
  });

  final String assetPath;
  final String? imageUrl;
  final String? lottieUrl;

  @override
  Widget build(BuildContext context) {
    final image = imageUrl?.trim();
    if (image != null && image.isNotEmpty) {
      return _NetworkBannerImage(
        url: image,
        fallbackAssetPath: assetPath,
      );
    }

    final url = lottieUrl?.trim();
    if (url == null || url.isEmpty) {
      // If no remote asset AND no local fallback, show nothing.
      if (assetPath.isEmpty) return const SizedBox.expand();
      return _AssetDotLottieAnimation(assetPath: assetPath);
    }

    return _NetworkUploadedAnimation(
      url: url,
      fallbackAssetPath: assetPath,
    );
  }
}

class _NetworkBannerImage extends StatelessWidget {
  const _NetworkBannerImage({
    required this.url,
    required this.fallbackAssetPath,
  });

  final String url;
  final String fallbackAssetPath;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = ApiConstants.proxyMediaUrl(url) ?? url;
    final optimized = ApiConstants.optimizedMedia(
      resolvedUrl,
      profile: CustomerImageProfile.banner,
    );
    return SizedBox.expand(
      child: AppImage(
        imageUrl: optimized.url ?? resolvedUrl,
        memCacheWidth: optimized.memCacheWidth,
        memCacheHeight: optimized.memCacheHeight,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        placeholder: const SizedBox.expand(),
        errorWidget: fallbackAssetPath.isNotEmpty
            ? _AssetDotLottieAnimation(assetPath: fallbackAssetPath)
            : const SizedBox.expand(),
      ),
    );
  }
}

class _NetworkUploadedAnimation extends StatelessWidget {
  const _NetworkUploadedAnimation({
    required this.url,
    required this.fallbackAssetPath,
  });

  final String url;
  final String fallbackAssetPath;

  @override
  Widget build(BuildContext context) {
    final shouldAnimate = TickerMode.valuesOf(context).enabled;
    return FutureBuilder<LoadedRemoteAnimation>(
      key: ValueKey<String>(url),
      future: RemoteAnimationLoader.load(url),
      builder: (
        BuildContext context,
        AsyncSnapshot<LoadedRemoteAnimation> snapshot,
      ) {
        if (snapshot.hasError) {
          assert(() {
            debugPrint(
              '[AnimatedBanner] Remote animation error for $url: ${snapshot.error}',
            );
            return true;
          }());
          if (fallbackAssetPath.isEmpty) return const SizedBox.expand();
          return _AssetDotLottieAnimation(assetPath: fallbackAssetPath);
        }

        final LoadedRemoteAnimation? loaded = snapshot.data;
        if (loaded == null) {
          if (fallbackAssetPath.isEmpty) return const SizedBox.expand();
          return _AssetDotLottieAnimation(assetPath: fallbackAssetPath);
        }

        assert(() {
          debugPrint('[AnimatedBanner] Remote animation loaded for $url');
          return true;
        }());

        final Uint8List? animationBytes = _primaryDotLottieAnimation(
          loaded.dotLottie,
        );
        if (animationBytes == null) {
          if (fallbackAssetPath.isEmpty) return const SizedBox.expand();
          return _AssetDotLottieAnimation(assetPath: fallbackAssetPath);
        }

        return Lottie.memory(
          animationBytes,
          fit: BoxFit.fitWidth,
          repeat: shouldAnimate,
          animate: shouldAnimate,
          frameRate: FrameRate.composition,
          renderCache: RenderCache.drawingCommands,
          addRepaintBoundary: true,
          filterQuality: FilterQuality.high,
          imageProviderFactory: (LottieImageAsset asset) {
            final Uint8List? bytes = _dotLottieImageBytes(
              loaded.dotLottie,
              asset.fileName,
            );
            if (bytes != null) {
              return MemoryImage(bytes);
            }

            assert(() {
              debugPrint(
                '[AnimatedBanner] Missing remote dotLottie image for ${asset.fileName} from $url',
              );
              return true;
            }());
            return MemoryImage(_transparentPixelPng);
          },
        );
      },
    );
  }
}

class _AssetDotLottieAnimation extends StatelessWidget {
  const _AssetDotLottieAnimation({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    // If no asset path is provided, show nothing — old campaign assets should
    // never render as fallback in production.
    if (assetPath.isEmpty) return const SizedBox.expand();
    final shouldAnimate = TickerMode.valuesOf(context).enabled;
    return Lottie.asset(
      assetPath,
      fit: BoxFit.fitWidth,
      repeat: shouldAnimate,
      animate: shouldAnimate,
      frameRate: FrameRate.composition,
      renderCache: RenderCache.drawingCommands,
      addRepaintBoundary: true,
      filterQuality: FilterQuality.high,
      decoder: _decodeUploadedLottie,
    );
  }
}

Future<LottieComposition?> _decodeUploadedLottie(List<int> bytes) async {
  try {
    final zippedComposition = await LottieComposition.decodeZip(
      bytes,
      filePicker: _pickAnimationArchiveFile,
    );
    if (zippedComposition != null) {
      return zippedComposition;
    }
  } catch (_) {
    // Fall back to JSON parsing below.
  }

  try {
    return await LottieComposition.decodeGZip(bytes);
  } catch (_) {
    return null;
  }
}

ArchiveFile? _pickAnimationArchiveFile(List<ArchiveFile> files) {
  ArchiveFile? selected;

  for (final file in files) {
    final lowerName = file.name.toLowerCase();
    if (lowerName.startsWith('animations/') && lowerName.endsWith('.json')) {
      selected = file;
      break;
    }
  }

  selected ??= _firstNonManifestJson(files);
  selected ??= _firstJson(files);

  if (selected == null) {
    return null;
  }

  try {
    final dynamic content = selected.content;
    final List<int> rawBytes = content is List<int> ? content : const <int>[];
    if (rawBytes.isEmpty) {
      return selected;
    }

    final dynamic decoded = jsonDecode(utf8.decode(rawBytes));
    if (decoded is! Map<String, dynamic>) {
      return selected;
    }

    final dynamic assets = decoded['assets'];
    if (assets is! List) {
      return selected;
    }

    bool changed = false;
    for (final dynamic asset in assets) {
      if (asset is! Map) {
        continue;
      }

      final dynamic rawDirectory = asset['u'];
      if (rawDirectory is String && rawDirectory.startsWith('/')) {
        asset['u'] = rawDirectory.replaceFirst(RegExp('^/+'), '');
        changed = true;
      }
    }

    if (!changed) {
      return selected;
    }

    final normalizedBytes = utf8.encode(jsonEncode(decoded));
    return ArchiveFile(
      selected.name,
      normalizedBytes.length,
      normalizedBytes,
    );
  } catch (_) {
    return selected;
  }
}

ArchiveFile? _firstNonManifestJson(List<ArchiveFile> files) {
  for (final file in files) {
    final lowerName = file.name.toLowerCase();
    if (lowerName.endsWith('.json') && lowerName != 'manifest.json') {
      return file;
    }
  }

  return null;
}

ArchiveFile? _firstJson(List<ArchiveFile> files) {
  for (final file in files) {
    if (file.name.toLowerCase().endsWith('.json')) {
      return file;
    }
  }

  return null;
}

Uint8List? _primaryDotLottieAnimation(DotLottie dotLottie) {
  if (dotLottie.animations.isEmpty) {
    return null;
  }
  return dotLottie.animations.values.first;
}

Uint8List? _dotLottieImageBytes(DotLottie dotLottie, String fileName) {
  final String normalized = fileName.replaceFirst(RegExp('^/+'), '');
  return dotLottie.images[normalized] ??
      dotLottie.images[fileName] ??
      dotLottie.images['images/$normalized'] ??
      dotLottie.images[normalized.split('/').last];
}

final Uint8List _transparentPixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jxN8AAAAASUVORK5CYII=',
);

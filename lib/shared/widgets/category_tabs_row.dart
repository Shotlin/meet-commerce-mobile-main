import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/models/category_model.dart';
import 'package:bakaloo_flutter_app/core/providers/store_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_provider.dart';

class CategoryTabsRow extends ConsumerWidget {
  const CategoryTabsRow({
    this.textOnly = false,
    this.listPadding,
    this.rowHeight,
    super.key,
  });

  final bool textOnly;
  final EdgeInsetsGeometry? listPadding;
  final double? rowHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(selectedStoreProvider);
    final selectedId = ref.watch(selectedCategoryIdProvider);
    // PERF: Only watch the categoryTabs sub-field, not the entire RemoteTheme.
    final categoryTabsTheme = ref.watch(
      activeTabThemeProvider.select((t) => t.sections.categoryTabs),
    );
    // PERF: Only watch the tabs list, not the full async response.
    final List<TabThemeEntry>? asyncTabs = ref
        .watch(tabThemesProvider.select((a) => a.asData?.value.tabs));
    final List<TabThemeEntry>? snapshotTabs =
        ref.watch(tabThemesSnapshotProvider)?.tabs;
    final List<TabThemeEntry>? remoteTabs =
        (snapshotTabs != null && snapshotTabs.isNotEmpty)
            ? snapshotTabs
            : (asyncTabs != null && asyncTabs.isNotEmpty)
                ? asyncTabs
                : null;
    final bool useRemoteTabs = remoteTabs != null && remoteTabs.isNotEmpty;
    final String effectiveSelectedId =
        _resolveSelectedTabId(selectedId, remoteTabs);
    final localCategories =
        storeCategoryMap[store.id] ?? storeCategoryMap['zepto']!;
    final resolvedPadding =
        (listPadding ?? EdgeInsets.symmetric(horizontal: 12.w))
            .resolve(Directionality.of(context));
    final resolvedHeight = rowHeight ?? (textOnly ? 44.h : 72.h);
    final defaultGap = textOnly ? 10.w : 6.w;
    final itemCount =
        useRemoteTabs ? remoteTabs.length : localCategories.length;
    final itemSpecs = List<_CategoryTabSpec>.generate(itemCount, (index) {
      if (useRemoteTabs) {
        final TabThemeEntry tab = remoteTabs[index];
        final bool isSelected = tab.tabKey == effectiveSelectedId;
        final double naturalWidth =
            textOnly ? math.max(52.w, tab.tabLabel.length * 7.2.w) : 72.w;

        return _CategoryTabSpec(
          naturalWidth: naturalWidth,
          minWidth: textOnly ? naturalWidth : 60.w,
          builder: (double width) => _buildRemoteTab(
            ref: ref,
            categoryTabsTheme: categoryTabsTheme,
            entry: tab,
            isSelected: isSelected,
            width: width,
          ),
        );
      }

      final cat = localCategories[index];
      // Empty selectedId is the "no explicit selection yet" sentinel; the
      // first local category is always 'all', so highlight that by default.
      final bool isSelected =
          cat.id == selectedId || (selectedId.isEmpty && index == 0);

      void onTap() {
        HapticFeedback.selectionClick();
        ref.read(selectedCategoryIdProvider.notifier).select(cat.id);
      }

      if (textOnly) {
        final double naturalWidth = math.max(52.w, cat.label.length * 7.2.w);
        return _CategoryTabSpec(
          naturalWidth: naturalWidth,
          minWidth: naturalWidth,
          builder: (double width) => _CategoryTextTab(
            category: cat,
            isSelected: isSelected,
            onTap: onTap,
            textColor: categoryTabsTheme.textColor,
            indicatorColor: categoryTabsTheme.indicatorColor,
            width: width,
          ),
        );
      }

      return _CategoryTabSpec(
        naturalWidth: 72.w,
        minWidth: 60.w,
        builder: (double width) => _CategoryTab(
          category: cat,
          isSelected: isSelected,
          onTap: onTap,
          textColor: categoryTabsTheme.textColor,
          indicatorColor: categoryTabsTheme.indicatorColor,
          width: width,
        ),
      );
    });

    return SizedBox(
      height: resolvedHeight,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double viewportWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final _CategoryTabLayout layout = _CategoryTabLayout.resolve(
            viewportWidth: viewportWidth,
            padding: resolvedPadding,
            gap: defaultGap,
            items: itemSpecs,
            allowCompaction: !textOnly,
          );
          final children = List<Widget>.generate(
            itemSpecs.length,
            (int index) => itemSpecs[index].builder(layout.widths[index]),
          );

          if (layout.useStaticRow) {
            return Padding(
              padding: resolvedPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _withSpacing(children, layout.gap),
              ),
            );
          }

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: resolvedPadding,
            itemCount: children.length,
            separatorBuilder: (_, __) => Gap(layout.gap),
            itemBuilder: (BuildContext context, int index) => children[index],
          );
        },
      ),
    );
  }

  String _resolveSelectedTabId(
    String selectedId,
    List<TabThemeEntry>? remoteTabs,
  ) {
    if (remoteTabs == null || remoteTabs.isEmpty) {
      return selectedId;
    }

    if (remoteTabs.any((tab) => tab.tabKey == selectedId)) {
      return selectedId;
    }

    return resolveDefaultTab(remoteTabs).tabKey;
  }

  Widget _buildRemoteTab({
    required WidgetRef ref,
    required CategoryTabsTheme categoryTabsTheme,
    required TabThemeEntry entry,
    required bool isSelected,
    required double width,
  }) {
    final Color foregroundColor = isSelected
        ? categoryTabsTheme.textColor
        : categoryTabsTheme.textColor.withValues(alpha: 0.72);

    void onTap() {
      HapticFeedback.selectionClick();
      ref.read(selectedCategoryIdProvider.notifier).select(entry.tabKey);
    }

    if (textOnly) {
      return GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(
            children: <Widget>[
              Expanded(
                child: Center(
                  child: Text(
                    entry.tabLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.2.sp,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: foregroundColor,
                      height: 1,
                    ),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 5.h,
                width: isSelected ? width : 0,
                decoration: BoxDecoration(
                  color: isSelected
                      ? categoryTabsTheme.indicatorColor
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(999),
                    topRight: Radius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        child: Column(
          children: <Widget>[
            if (entry.tabIconUrl != null)
              SizedBox(
                width: 46.w,
                height: 46.w,
                // FIX: Use CachedNetworkImage directly instead of AppImage
                // (which wraps ScrollAwareImageProvider). The sticky tab bar
                // is NOT inside a scrollable context, so ScrollAwareImageProvider
                // defers loading indefinitely and the icon never renders.
                // Also resolve the URL via ApiConstants to sanitize Cloudinary
                // transform params consistently.
                child: CachedNetworkImage(
                  imageUrl: ApiConstants.resolveMediaUrl(entry.tabIconUrl) ??
                      entry.tabIconUrl!,
                  width: 46.w,
                  height: 46.w,
                  memCacheWidth: 200,
                  memCacheHeight: 200,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  fadeInDuration: const Duration(milliseconds: 150),
                  placeholder: (context, url) => Icon(
                    Icons.category_rounded,
                    size: 30.sp,
                    color: foregroundColor,
                  ),
                  errorWidget: (context, url, error) => Icon(
                    Icons.category_rounded,
                    size: 30.sp,
                    color: foregroundColor,
                  ),
                ),
              )
            else
              SizedBox(
                width: 46.w,
                height: 46.w,
                child: Icon(
                  Icons.category_rounded,
                  size: 30.sp,
                  color: foregroundColor,
                ),
              ),
            Gap(1.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 2.w),
              child: Text(
                entry.tabLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.8.sp,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: foregroundColor,
                ),
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 5.h,
                width: isSelected ? width * 0.78 : 0,
                decoration: BoxDecoration(
                  color: isSelected
                      ? categoryTabsTheme.indicatorColor
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(999),
                    topRight: Radius.circular(999),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<Widget> _withSpacing(List<Widget> children, double gap) {
  if (children.length < 2 || gap <= 0) {
    return children;
  }

  final spacedChildren = <Widget>[];
  for (int index = 0; index < children.length; index++) {
    if (index > 0) {
      spacedChildren.add(SizedBox(width: gap));
    }
    spacedChildren.add(children[index]);
  }
  return spacedChildren;
}

class _CategoryTabSpec {
  const _CategoryTabSpec({
    required this.naturalWidth,
    required this.minWidth,
    required this.builder,
  });

  final double naturalWidth;
  final double minWidth;
  final Widget Function(double width) builder;
}

class _CategoryTabLayout {
  const _CategoryTabLayout({
    required this.widths,
    required this.gap,
    required this.useStaticRow,
  });

  final List<double> widths;
  final double gap;
  final bool useStaticRow;

  static _CategoryTabLayout resolve({
    required double viewportWidth,
    required EdgeInsets padding,
    required double gap,
    required List<_CategoryTabSpec> items,
    required bool allowCompaction,
  }) {
    if (items.isEmpty) {
      return const _CategoryTabLayout(
        widths: <double>[],
        gap: 0,
        useStaticRow: true,
      );
    }

    final double availableWidth =
        math.max(0, viewportWidth - padding.horizontal);
    final List<double> naturalWidths =
        items.map((item) => item.naturalWidth).toList(growable: false);
    final double naturalContentWidth =
        naturalWidths.fold<double>(0, (sum, width) => sum + width) +
            gap * math.max(0, items.length - 1);

    if (naturalContentWidth <= availableWidth) {
      final double distributedGap = items.length > 1
          ? (availableWidth -
                  naturalWidths.fold<double>(0, (sum, width) => sum + width)) /
              (items.length - 1)
          : 0;
      return _CategoryTabLayout(
        widths: naturalWidths,
        gap: distributedGap,
        useStaticRow: true,
      );
    }

    if (allowCompaction && items.length > 1) {
      final double minimumWidth = items.fold<double>(
        0,
        (maxWidth, item) => math.max(maxWidth, item.minWidth),
      );
      final double naturalWidth = items.fold<double>(
        double.infinity,
        (minWidth, item) => math.min(minWidth, item.naturalWidth),
      );
      final double compactWidth =
          ((availableWidth - gap * (items.length - 1)) / items.length)
              .clamp(minimumWidth, naturalWidth);

      if (compactWidth * items.length + gap * (items.length - 1) <=
          availableWidth) {
        return _CategoryTabLayout(
          widths: List<double>.filled(items.length, compactWidth),
          gap: gap,
          useStaticRow: true,
        );
      }
    }

    return _CategoryTabLayout(
      widths: naturalWidths,
      gap: gap,
      useStaticRow: false,
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.category,
    required this.isSelected,
    required this.onTap,
    required this.textColor,
    required this.indicatorColor,
    required this.width,
  });

  final CategoryModel category;
  final bool isSelected;
  final VoidCallback onTap;
  final Color textColor;
  final Color indicatorColor;
  final double width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        height: double.infinity,
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            Image.asset(
              category.iconPath,
              width: 44.w,
              height: 44.h,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              color: textColor.withValues(alpha: isSelected ? 1 : 0.72),
              colorBlendMode: BlendMode.srcIn,
              errorBuilder: (_, __, ___) => Icon(
                Icons.category_rounded,
                size: 30.sp,
                color: textColor.withValues(alpha: isSelected ? 1 : 0.72),
              ),
            ),
            Gap(1.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 2.w),
              child: Text(
                category.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.8.sp,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? textColor
                      : textColor.withValues(alpha: 0.72),
                ),
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 5.h,
                width: isSelected ? width * 0.78 : 0,
                decoration: BoxDecoration(
                  color: isSelected ? indicatorColor : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(999),
                    topRight: Radius.circular(999),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTextTab extends StatelessWidget {
  const _CategoryTextTab({
    required this.category,
    required this.isSelected,
    required this.onTap,
    required this.textColor,
    required this.indicatorColor,
    required this.width,
  });

  final CategoryModel category;
  final bool isSelected;
  final VoidCallback onTap;
  final Color textColor;
  final Color indicatorColor;
  final double width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          children: <Widget>[
            Expanded(
              child: Center(
                child: Text(
                  category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.2.sp,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? textColor
                        : textColor.withValues(alpha: 0.72),
                    height: 1,
                  ),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 5.h,
              width: isSelected ? width : 0,
              decoration: BoxDecoration(
                color: isSelected ? indicatorColor : Colors.transparent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(999),
                  topRight: Radius.circular(999),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

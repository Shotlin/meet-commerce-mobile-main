import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/config/app_config.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_model.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_provider.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/widgets/section_registry.dart';

class DynamicHomeSections extends ConsumerWidget {
  const DynamicHomeSections({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<SectionManifestEntry> sections = ref.watch(
      activeSectionManifestProvider.select(
        (m) => m.sections.where(_isSectionAllowed).toList(growable: false),
      ),
    );

    // Use .select() to avoid rebuilding the full list on unrelated theme changes.
    final int sectionCount = sections.length;

    if (sectionCount == 0) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    // Pass theme down only when sections actually need it; each slot will
    // read the theme itself via ref so it only rebuilds when its own section
    // data changes (not when unrelated theme fields change).
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          final SectionManifestEntry entry = sections[index];
          return _DynamicSectionSlot(
            key: ValueKey<String>('${entry.type}_${entry.id}'),
            entry: entry,
          );
        },
        childCount: sections.length,
      ),
    );
  }
}

bool _isSectionAllowed(SectionManifestEntry entry) {
  if (AppConfig.allowRemoteMarketingAssets) {
    return true;
  }

  // These section types can display arbitrary dashboard-supplied campaign
  // images or animations. Until a branded asset review has been completed,
  // suppress them on Web while keeping live catalogue/product sections.
  switch (entry.type) {
    case SectionType.animatedBanner:
    case SectionType.feeStrip:
    case SectionType.seasonalMosaic:
    case SectionType.promoCarousel:
    case SectionType.bankOffers:
    case SectionType.customBanner:
    case SectionType.archedProductShowcase:
      return false;
    case SectionType.roundCategoryIcons:
    case SectionType.categoryProductGrid:
    case SectionType.productCarousel:
    case SectionType.trendingProducts:
    case SectionType.textHeader:
    case SectionType.spacer:
      return true;
  }
}

class _DynamicSectionSlot extends ConsumerWidget {
  const _DynamicSectionSlot({
    required this.entry,
    super.key,
  });

  final SectionManifestEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!entry.visible) {
      return const SizedBox.shrink();
    }

    final builder = sectionRegistry[entry.type];
    if (builder == null) {
      return const SizedBox.shrink();
    }

    // Each section slot reads theme on its own — this means only THIS slot
    // rebuilds when the theme changes, not all siblings.
    final RemoteTheme theme = ref.watch(activeTabThemeProvider);

    return RepaintBoundary(
      child: builder(entry, theme, ref),
    );
  }
}

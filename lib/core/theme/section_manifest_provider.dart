import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/config/app_config.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_service.dart';
import 'package:bakaloo_flutter_app/core/storefront/layout_keys.dart';
import 'package:bakaloo_flutter_app/core/storefront/layout_providers.dart';
import 'package:bakaloo_flutter_app/core/storefront/storefront_scope.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_model.dart';

export 'package:bakaloo_flutter_app/core/theme/remote_theme_provider.dart'
    show activeTabKeyProvider;

final StreamProvider<Map<String, dynamic>> socketSectionUpdateStreamProvider =
    StreamProvider<Map<String, dynamic>>((Ref ref) {
  return ref.watch(socketServiceProvider).sectionUpdateStream;
});

/// Key of the manifest being shown: active (store, shop, price mode) + tab.
final Provider<SectionKey> activeSectionKeyProvider =
    Provider<SectionKey>((Ref ref) {
  final StorefrontScope scope = ref.watch(storefrontScopeProvider);
  final String tabKey = ref.watch(activeTabKeyProvider);
  return scope.sectionKey(tabKey);
});

enum SectionsStatus {
  /// First load for this (store, shop, mode, tab): nothing to show yet.
  loading,

  /// A manifest is held (it may legitimately contain zero sections).
  ready,

  /// First load failed and nothing is held.
  failed,
}

/// What the home body renders. Equality is by status + list identity so a
/// revalidation that changes nothing never rebuilds the section list.
@immutable
class ActiveSections {
  const ActiveSections({required this.status, required this.sections});

  const ActiveSections.loading()
      : status = SectionsStatus.loading,
        sections = const <SectionManifestEntry>[];

  final SectionsStatus status;
  final List<SectionManifestEntry> sections;

  bool get isEmpty => sections.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveSections &&
          other.status == status &&
          identical(other.sections, sections);

  @override
  int get hashCode => Object.hash(status, identityHashCode(sections));
}

/// Sections of the active tab. Products inside are already resolved by the
/// backend for the customer's shop and price mode, so this is the single
/// source of section content.
final Provider<ActiveSections> activeSectionsProvider =
    Provider<ActiveSections>((Ref ref) {
  final SectionKey key = ref.watch(activeSectionKeyProvider);
  final AsyncValue<SectionManifestResponse> manifest =
      ref.watch(sectionManifestControllerProvider(key));

  final SectionManifestResponse? value = manifest.value;
  if (value != null) {
    return ActiveSections(
      status: SectionsStatus.ready,
      sections: _allowedSections(value),
    );
  }
  if (manifest.hasError) {
    return const ActiveSections(
      status: SectionsStatus.failed,
      sections: <SectionManifestEntry>[],
    );
  }
  return const ActiveSections.loading();
});

final Expando<List<SectionManifestEntry>> _allowedCache =
    Expando<List<SectionManifestEntry>>('allowedSections');

List<SectionManifestEntry> _allowedSections(SectionManifestResponse response) {
  return _allowedCache[response] ??= response.sections
      .where(_isSectionAllowed)
      .toList(growable: false);
}

bool _isSectionAllowed(SectionManifestEntry entry) {
  if (!entry.visible) {
    return false;
  }
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

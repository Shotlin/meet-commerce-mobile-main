import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/core/models/store_model.dart';
import 'package:bakaloo_flutter_app/core/providers/store_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_provider.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/providers/home_provider.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/widgets/dynamic_home_sections.dart';
import 'package:bakaloo_flutter_app/routing/app_router.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/shared/widgets/category_tabs_row.dart';
import 'package:bakaloo_flutter_app/shared/widgets/delivery_promo_bar.dart';
import 'package:bakaloo_flutter_app/shared/widgets/home_header.dart';
import 'package:bakaloo_flutter_app/shared/widgets/home_search_bar.dart';
import 'package:bakaloo_flutter_app/shared/utils/address_utils.dart';
import 'package:bakaloo_flutter_app/shared/widgets/address_bottom_sheet.dart';
import 'package:bakaloo_flutter_app/shared/widgets/shared_painters.dart';

class StoreScreenShell extends ConsumerStatefulWidget {
  const StoreScreenShell({required this.storeIndex, super.key});

  /// Index into [appStores] list:
  /// 0 = Bakaloo (zepto), 1 = off_zone, 2 = super_mall, 3 = cafe
  final int storeIndex;

  @override
  ConsumerState<StoreScreenShell> createState() => _StoreScreenShellState();
}

class _StoreScreenShellState extends ConsumerState<StoreScreenShell>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;
  late final ScrollController _scrollController;
  late final ProviderSubscription<AsyncValue<Map<String, dynamic>>>
      _themeSocketSub;
  late final ProviderSubscription<AsyncValue<Map<String, dynamic>>>
      _sectionSocketSub;
  late final ProviderSubscription<Timer> _themeRefreshTimerSub;
  bool _isThemeLayoutRefreshInFlight = false;

  StoreModel get _store => appStores[widget.storeIndex];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController = ScrollController();
    _themeSocketSub = ref.listenManual(
      socketThemeUpdateStreamProvider,
      (previous, next) {
        next.whenData((event) {
          unawaited(handleThemeSocketEvent(ref, event));
        });
      },
    );
    _sectionSocketSub = ref.listenManual(
      socketSectionUpdateStreamProvider,
      (previous, next) {
        next.whenData((event) {
          unawaited(handleSectionSocketEvent(ref, event));
        });
      },
    );
    _themeRefreshTimerSub = ref.listenManual(
      themeRefreshTimerProvider,
      (_, __) {},
    );

    // Set the store globally — this cascades to:
    // → sectionManifestProvider (re-fetches with new store_key)
    // → tabThemesProvider (re-fetches tabs for this store)
    // → CategoryTabsRow (re-renders with new tabs)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(selectedStoreProvider.notifier).select(_store);
      ref.read(selectedCategoryIdProvider.notifier).select('');
    });

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _themeSocketSub.close();
    _sectionSocketSub.close();
    _themeRefreshTimerSub.close();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshThemeDrivenLayout());
    }
  }

  Future<void> _refreshThemeDrivenLayout() async {
    if (!mounted || _isThemeLayoutRefreshInFlight) {
      return;
    }

    _isThemeLayoutRefreshInFlight = true;
    try {
      final activeTabKey = ref.read(activeTabKeyProvider);
      await Future.wait<void>(<Future<void>>[
        refreshCurrentStoreThemes(ref),
        refreshSectionManifest(ref, activeTabKey),
      ]);
    } finally {
      _isThemeLayoutRefreshInFlight = false;
    }
  }

  Future<void> _refresh() async {
    final activeTabKey = ref.read(activeTabKeyProvider);
    ref
      ..invalidate(homeProvider)
      ..invalidate(tabThemesProvider)
      ..invalidate(sectionManifestProvider(activeTabKey))
      ..invalidate(activeSectionManifestProvider);
    await _refreshThemeDrivenLayout();
  }

  void _openSearch() => context.go(RouteNames.search);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final store = ref.watch(selectedStoreProvider);
    final hasSnapshotTheme = ref.watch(
      tabThemesSnapshotProvider.select(
        (snapshot) => snapshot?.tabs.isNotEmpty ?? false,
      ),
    );
    final hasAsyncTheme = ref.watch(
      tabThemesProvider.select(
        (tabThemesAsync) =>
            tabThemesAsync.asData?.value.tabs.isNotEmpty ?? false,
      ),
    );
    final bool hasResolvedStoreTheme = hasSnapshotTheme || hasAsyncTheme;
    final statusBarBrightness = ref.watch(
      activeTabThemeProvider.select((theme) => theme.meta.statusBarBrightness),
    );
    final showCategoryTabs = ref.watch(
      activeTabThemeProvider.select(
        (theme) => theme.sections.categoryTabs.visible,
      ),
    );
    final resolvedTopBarTheme = TopBarTheme(
      backgroundColor: ref.watch(
        activeTabThemeProvider.select(
          (theme) => theme.sections.topBar.backgroundColor,
        ),
      ),
      textColor: ref.watch(
        activeTabThemeProvider
            .select((theme) => theme.sections.topBar.textColor),
      ),
    );
    final resolvedSelectorTheme = StoreSelectorTheme(
      backgroundColor: ref.watch(
        activeTabThemeProvider.select(
          (theme) => theme.sections.storeSelector.backgroundColor,
        ),
      ),
      activeChipColor: ref.watch(
        activeTabThemeProvider.select(
          (theme) => theme.sections.storeSelector.activeChipColor,
        ),
      ),
    );
    final resolvedSearchTheme = SearchZoneTheme(
      backgroundColor: ref.watch(
        activeTabThemeProvider.select(
          (theme) => theme.sections.searchZone.backgroundColor,
        ),
      ),
      waveColor: ref.watch(
        activeTabThemeProvider.select(
          (theme) => theme.sections.searchZone.waveColor,
        ),
      ),
      searchHints: () {
        final serializedHints = ref.watch(
          activeTabThemeProvider.select(
            (theme) => theme.sections.searchZone.searchHints.join('\u0001'),
          ),
        );
        return serializedHints.isEmpty
            ? const <String>[]
            : serializedHints.split('\u0001');
      }(),
      promoBoxImageUrl: ref.watch(
        activeTabThemeProvider.select(
          (theme) => theme.sections.searchZone.promoBoxImageUrl,
        ),
      ),
    );
    final _StoreChromeTheme chromeTheme = hasResolvedStoreTheme
        ? _StoreChromeTheme(
            topBarColor: resolvedTopBarTheme.backgroundColor,
            topBarTheme: resolvedTopBarTheme,
            selectorTheme: resolvedSelectorTheme,
            searchTheme: resolvedSearchTheme,
            searchZoneColor: resolvedSearchTheme.backgroundColor,
            waveColor: resolvedSearchTheme.waveColor,
            refreshColor: resolvedSelectorTheme.activeChipColor,
          )
        : _StoreChromeTheme.resolve(
            store: store,
            theme: RemoteTheme.defaults(),
            hasResolvedStoreTheme: false,
          );
    final bool useLightStatusIcons = hasResolvedStoreTheme
        ? statusBarBrightness == 'light'
        : ThemeData.estimateBrightnessForColor(chromeTheme.topBarColor) ==
            Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarIconBrightness:
            useLightStatusIcons ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            useLightStatusIcons ? Brightness.dark : Brightness.light,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: <Widget>[
            RepaintBoundary(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: chromeTheme.refreshColor,
                child: CustomScrollView(
                  controller: _scrollController,
                  cacheExtent: 100,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: <Widget>[
                    // ── Sliver 1: Colored header ──
                    SliverToBoxAdapter(
                      child: ColoredBox(
                        color: chromeTheme.topBarColor,
                        child: Column(
                          children: <Widget>[
                            // Delivery header
                            Consumer(
                              builder: (context, ref, _) {
                                final currentUser = ref.watch(
                                  currentUserProvider,
                                );
                                final List<AddressEntity>? addresses =
                                    currentUser == null
                                        ? null
                                        : ref
                                            .watch(addressProvider)
                                            .asData
                                            ?.value;
                                final addressText = resolveAddressLabel(
                                  isLoggedIn: currentUser != null,
                                  addresses: addresses,
                                );
                                final deliveryEtaMinutes = ref.watch(
                                  tabThemesProvider.select(
                                    (tabThemesAsync) => tabThemesAsync
                                        .asData?.value.deliveryEtaMinutes,
                                  ),
                                );
                                return HomeHeader(
                                  addressText: addressText,
                                  onAddressTap: () =>
                                      showAddressSheet(context),
                                  onNotificationTap: () =>
                                      context.go(RouteNames.notifications),
                                  onWalletTap: () =>
                                      context.go(RouteNames.wallet),
                                  topBarTheme: chromeTheme.topBarTheme,
                                  searchZoneColor: chromeTheme.searchZoneColor,
                                  deliveryEtaMinutes: deliveryEtaMinutes,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: ColoredBox(
                        color: chromeTheme.searchZoneColor,
                        child: Column(
                          children: <Widget>[
                            SizedBox(
                              height: 6,
                              child: ClipPath(
                                clipper: const StoreToSearchWaveClipper(),
                                child: ColoredBox(
                                  color: chromeTheme.waveColor,
                                ),
                              ),
                            ),
                            HomeSearchBar(
                              onSearchTap: _openSearch,
                              searchTheme: chromeTheme.searchTheme,
                              outerPadding:
                                  const EdgeInsets.fromLTRB(12, 1, 0, 0),
                            ),
                            if (!showCategoryTabs) const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),

                    // ── Sliver 2: Category tabs (pinned) ──
                    if (showCategoryTabs)
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _CategoryTabDelegate(
                          backgroundColor: chromeTheme.searchZoneColor,
                        ),
                      ),

                    // ── Sliver 3: Dynamic sections (the magic) ──
                    DynamicHomeSections(
                      key: ValueKey(ref.watch(activeTabKeyProvider)),
                    ),

                    // ── Sliver 4: Bottom padding ──
                    SliverPadding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.paddingOf(context).bottom +
                            120 +
                            56, // +56 for promo bar
                      ),
                      sliver: const SliverToBoxAdapter(
                        child: SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: DeliveryPromoBar(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreChromeTheme {
  const _StoreChromeTheme({
    required this.topBarColor,
    required this.topBarTheme,
    required this.selectorTheme,
    required this.searchTheme,
    required this.searchZoneColor,
    required this.waveColor,
    required this.refreshColor,
  });

  final Color topBarColor;
  final TopBarTheme topBarTheme;
  final StoreSelectorTheme selectorTheme;
  final SearchZoneTheme searchTheme;
  final Color searchZoneColor;
  final Color waveColor;
  final Color refreshColor;

  factory _StoreChromeTheme.resolve({
    required StoreModel store,
    required RemoteTheme theme,
    required bool hasResolvedStoreTheme,
  }) {
    if (!hasResolvedStoreTheme) {
      final Color softenedStoreColor = Color.lerp(
            store.backgroundColor,
            Colors.white,
            0.12,
          ) ??
          store.backgroundColor;
      return _StoreChromeTheme(
        topBarColor: store.backgroundColor,
        topBarTheme: TopBarTheme(
          backgroundColor: store.backgroundColor,
          textColor: store.textColor,
        ),
        selectorTheme: StoreSelectorTheme(
          backgroundColor: store.backgroundColor,
          activeChipColor: store.chipActiveColor,
        ),
        searchTheme: SearchZoneTheme(
          backgroundColor: softenedStoreColor,
          waveColor: store.backgroundColor,
          searchHints: SearchZoneTheme.defaults().searchHints,
          promoBoxImageUrl: null,
        ),
        searchZoneColor: softenedStoreColor,
        waveColor: store.backgroundColor,
        refreshColor: store.chipActiveColor,
      );
    }

    return _StoreChromeTheme(
      topBarColor: theme.sections.topBar.backgroundColor,
      topBarTheme: theme.sections.topBar,
      selectorTheme: theme.sections.storeSelector,
      searchTheme: theme.sections.searchZone,
      searchZoneColor: theme.sections.searchZone.backgroundColor,
      waveColor: theme.sections.searchZone.waveColor,
      refreshColor: theme.sections.storeSelector.activeChipColor,
    );
  }
}

/// Delegate for pinning CategoryTabsRow on scroll.
class _CategoryTabDelegate extends SliverPersistentHeaderDelegate {
  const _CategoryTabDelegate({required this.backgroundColor});

  final Color backgroundColor;

  @override
  double get minExtent => 72;
  @override
  double get maxExtent => 72;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: backgroundColor,
      child: const CategoryTabsRow(),
    );
  }

  @override
  bool shouldRebuild(covariant _CategoryTabDelegate oldDelegate) =>
      backgroundColor != oldDelegate.backgroundColor;
}

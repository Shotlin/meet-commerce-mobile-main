import 'dart:async';
import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/branding/branding_provider.dart';
import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/tab_home_content_model.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';
import 'package:bakaloo_flutter_app/shared/utils/address_utils.dart';
import 'package:bakaloo_flutter_app/features/categories/domain/entities/category_entity.dart';
import 'package:bakaloo_flutter_app/features/categories/presentation/providers/category_provider.dart';
import 'package:bakaloo_flutter_app/features/home/domain/entities/banner_entity.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/providers/banner_provider.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/providers/home_provider.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/widgets/dynamic_home_sections.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/widgets/order_tracking_top_banner.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/purchase_limits/presentation/providers/purchase_limits_provider.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:bakaloo_flutter_app/routing/app_router.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/core/providers/store_provider.dart';
import 'package:bakaloo_flutter_app/shared/widgets/category_tabs_row.dart';
import 'package:bakaloo_flutter_app/shared/widgets/error_state.dart';
import 'package:bakaloo_flutter_app/shared/widgets/home_header.dart';
import 'package:bakaloo_flutter_app/shared/widgets/home_search_bar.dart';
import 'package:bakaloo_flutter_app/shared/widgets/store_closed_banner.dart';
import 'package:bakaloo_flutter_app/shared/widgets/product_card.dart';
import 'package:bakaloo_flutter_app/shared/widgets/skeleton_loader.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:bakaloo_flutter_app/features/location/presentation/providers/location_prompt_provider.dart';
import 'package:bakaloo_flutter_app/features/notifications/presentation/providers/notification_provider.dart';
import 'package:bakaloo_flutter_app/features/location/presentation/widgets/location_prompt_sheet.dart';
import 'package:bakaloo_flutter_app/features/profile/presentation/providers/profile_provider.dart';
import 'package:bakaloo_flutter_app/features/profile/presentation/widgets/name_prompt_dialog.dart';
import 'package:bakaloo_flutter_app/shared/widgets/address_bottom_sheet.dart';

double _horizontalRailExtent(
  int index,
  int itemCount,
  double itemWidth,
  double separatorWidth,
) {
  if (itemCount <= 1 || index == itemCount - 1) {
    return itemWidth;
  }
  return itemWidth + separatorWidth;
}

/// Logical (design-unit) width for a card in the 3-column home grid.
///
/// The grid uses 16w horizontal padding on each side and two 10w gaps between
/// the three columns. [ProductCard] multiplies its `width` by `.w` internally,
/// so we return the design-unit width (raw px ÷ current width scale) to avoid
/// double-scaling.
double _threeColumnCardWidth(BuildContext context) {
  final double screenWidth = MediaQuery.sizeOf(context).width;
  final double horizontalPadding = 16.w * 2;
  final double totalGap = 10.w * 2;
  final double columnPx = (screenWidth - horizontalPadding - totalGap) / 3;
  final double scale = ScreenUtil().scaleWidth;
  return scale > 0 ? columnPx / scale : columnPx;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  late final ScrollController _homeScrollController;
  late final ProviderSubscription<AsyncValue<Map<String, dynamic>>>
      _themeSocketSub;
  late final ProviderSubscription<AsyncValue<Map<String, dynamic>>>
      _sectionSocketSub;
  late final ProviderSubscription<AsyncValue<Map<String, dynamic>>>
      _brandingSocketSub;
  late final ProviderSubscription<Timer> _themeRefreshTimerSub;
  late final ProviderSubscription<AuthState> _authStateSub;
  late final ProviderSubscription<AsyncValue<HomeScreenData>> _homeDataSub;
  late final ProviderSubscription<AsyncValue<TabHomeContentResponse?>>
      _tabHomeContentSub;
  // PHASE 4: Track active tab key so we can reset scroll/stage state on switch.
  late final ProviderSubscription<String> _tabKeySub;
  String _activeTabKey = 'all';
  final GlobalKey _topSearchZoneKey = GlobalKey();
  double? _stickyHeaderTriggerOffset;
  final ValueNotifier<double> _stickyHeaderProgress = ValueNotifier<double>(0);
  final ValueNotifier<int> _deferredSectionStage = ValueNotifier<int>(0);
  final ValueNotifier<bool> _isStickyHeaderActive = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isTopChromeMotionEnabled =
      ValueNotifier<bool>(true);
  bool _isThemeLayoutRefreshInFlight = false;
  List<CategoryEntity> _stagedCategories = const <CategoryEntity>[];
  List<CategoryEntity> _priorityCategories = const <CategoryEntity>[];
  List<CategoryEntity> _deferredCategories = const <CategoryEntity>[];
  List<BannerEntity> _banners = const <BannerEntity>[];
  List<ProductEntity> _homeFeaturedProducts = const <ProductEntity>[];
  List<_HomePromoData> _bannerCarouselCards = const <_HomePromoData>[];
  // ignore: unused_field
  List<ProductEntity> _managedSeasonalProducts = const <ProductEntity>[];
  List<ProductEntity> _managedFeaturedProducts = const <ProductEntity>[];
  // ignore: unused_field
  List<ProductEntity> _managedTrendingProducts = const <ProductEntity>[];
  // ignore: unused_field
  List<TabCategorySection> _managedCategorySections =
      const <TabCategorySection>[];
  // ignore: unused_field
  List<ProductEntity> _featuredPool = const <ProductEntity>[];
  final ValueNotifier<List<Widget>> _cachedStagedSlivers =
      ValueNotifier<List<Widget>>(const <Widget>[]);
  int _lastRenderedStage = -1;
  // Suppresses re-showing the prompt while the service stays disabled (e.g.
  // the user dismissed it without turning location on); reset to false the
  // moment the service flips back to enabled so a later disable in the same
  // session can prompt again. See _locationServiceStatusSub.
  bool _locationPromptShownThisSession = false;
  // True for the entire duration of an in-progress _maybeShowLocationPrompt
  // call, including while it's awaiting the sheet/screen the customer is
  // looking at. Distinct from _locationPromptShownThisSession (which is
  // deliberately reset to allow re-prompting after a later toggle) — this
  // one exists purely to stop a second call from starting while an earlier
  // one hasn't finished. Without it: tapping "Enable" while location is off
  // sends the customer to the OS location-settings screen with the sheet
  // still open (and this function still awaiting it) underneath; flipping
  // location on there fires the service-status-stream listener below, which
  // resets _locationPromptShownThisSession and calls this function again —
  // pushing a second sheet on top of the still-open first one. The second
  // sheet auto-detects, saves, and pops itself, which then reveals the
  // orphaned first sheet still showing its stale "turn on location"
  // message — mandatory, so the customer can't even swipe it away. Reported
  // bug: a stuck popup after granting location from a cold "location off,
  // no address" start, never happening when location was already on.
  bool _locationPromptInFlight = false;
  StreamSubscription<ServiceStatus>? _locationServiceStatusSub;
  // Guards against a second _maybeShowNamePrompt call stacking a duplicate
  // dialog while one check/dialog is already in flight. MUST only be set
  // to true once we've confirmed there's actually a logged-in user to
  // check — Home is reachable as a guest before login, and if this were
  // set unconditionally up front, the guest-mode no-op would permanently
  // poison it for the rest of this HomeScreen instance's lifetime (which
  // can span a later login, since Home is the always-mounted root — see
  // _authStateSub below): the dialog would then never show even after the
  // user logs in, which is exactly the same class of bug already fixed
  // for the location prompt (see _locationPromptShownThisSession above).
  bool _namePromptAttemptedThisSession = false;

  double get _stickyRevealStartDistance => 48.h;
  double get _stickyRevealEndDistance => 24.h;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _homeScrollController = ScrollController()..addListener(_handleHomeScroll);
    _themeSocketSub = ref.listenManual(
      socketThemeUpdateStreamProvider,
      (previous, next) {
        next.whenData((event) {
          unawaited(handleThemeSocketEvent(ref, event));
        });
      },
    );
    _brandingSocketSub = ref.listenManual(
      socketBrandingUpdateStreamProvider,
      (previous, next) {
        next.whenData((event) {
          unawaited(ref.read(brandingProvider.notifier).refresh());
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
    // HomeScreen (part of AppShell, the always-mounted root) can be built
    // before login completes — e.g. a guest view of Home. initState's own
    // one-shot _maybeShowLocationPrompt call below then runs while still
    // unauthenticated, finds nothing to do, and (being one-shot per
    // session) never runs again on its own. Without this listener, logging
    // in afterward never re-checks whether the address prompt should show
    // — it only appeared once the customer fully restarted the app, which
    // recreates this State fresh already logged in. Reported bug: "after
    // login... not show... but I refresh application then that pop-up
    // thing... coming."
    _authStateSub = ref.listenManual(authStateProvider, (previous, next) {
      if (next is AuthAuthenticated && previous is! AuthAuthenticated) {
        // Same reasoning as the location prompt above: a customer who
        // logged in from a guest view of Home never got this checked at
        // cold start (currentUserProvider was still null then), so it has
        // to be re-run here too, once we actually know who's logged in.
        unawaited(_maybeShowOnboardingPrompts());
      }
    });
    _deferredSectionStage.addListener(_rebuildStagedSlivers);
    // PHASE 4: Listen for tab changes and immediately reset scroll position
    // and deferred-section state so stale previous-tab content never bleeds
    // into the newly selected tab.
    _tabKeySub = ref.listenManual(
      selectedCategoryIdProvider,
      (previous, next) {
        if (previous == next || next == _activeTabKey) return;
        _activeTabKey = next;
        _onTabChanged();
      },
    );
    _homeDataSub = ref.listenManual(
      homeProvider,
      (previous, next) {
        next.whenData(_recomputeHomeData);
      },
      fireImmediately: true,
    );
    _tabHomeContentSub = ref.listenManual(
      selectedTabHomeContentProvider,
      (previous, next) {
        if (next case AsyncData(:final value?)) {
          _recomputeTabContent(value);
          return;
        }
        _clearTabContentCache();
      },
      fireImmediately: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateStickyHeaderTriggerOffset();
        _handleHomeScroll();
        // Initial check — slight delay so home UI settles first
        Future<void>.delayed(const Duration(milliseconds: 800), () {
          if (mounted) unawaited(_maybeShowOnboardingPrompts());
        });
      }
    });
    // Live-listen for the user toggling device location on/off while the
    // app stays in the foreground (e.g. via the quick-settings shade) —
    // on many Android versions this does NOT trigger didChangeAppLifecycleState,
    // so without this stream the prompt would only ever reappear after a full
    // background/foreground cycle.
    _locationServiceStatusSub =
        Geolocator.getServiceStatusStream().listen((status) {
      if (status == ServiceStatus.enabled) {
        // Guard against re-opening anything for a customer who's already
        // done — Android re-reports this status for reasons that have
        // nothing to do with the customer (not just them flipping the
        // quick-settings toggle), so this can fire well after they've
        // already completed their address. Resetting the flag
        // unconditionally used to let that stale event re-run the whole
        // detect flow — which, combined with a since-fixed bug where
        // detection always created a brand-new address instead of
        // updating the existing one, sent a customer with an already-
        // complete address straight back into the completion screen. This
        // check is deliberately independent of that fix (defense in
        // depth): even a future bug that re-creates an incomplete address
        // shouldn't be able to reopen this for someone who has a complete
        // one on file.
        final addresses = ref.read(addressProvider).asData?.value;
        final hasCompleteAddress = addresses != null &&
            addresses.any(
              (a) => a.isDefault && (a.addressLine2 ?? '').trim().isNotEmpty,
            );
        if (!hasCompleteAddress) {
          _locationPromptShownThisSession = false;
          // The whole point of nudging the customer to flip this toggle is
          // to get their address saved the moment it happens, not to wait
          // for them to come back later — _maybeShowLocationPrompt will
          // still show the sheet if there's no address yet, just
          // auto-triggered.
          unawaited(_maybeShowLocationPrompt());
        }
      } else if (status == ServiceStatus.disabled) {
        unawaited(_maybeShowLocationPrompt());
      }
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  void _handleHomeScroll() {
    if (!_homeScrollController.hasClients) {
      return;
    }

    // PHASE 4A: Stamp last scroll timestamp so themeRefreshTimerProvider
    // can detect active scroll and defer its cache-clearing invalidation.
    homeScrollLastEventMs = DateTime.now().millisecondsSinceEpoch;

    final pixels = _homeScrollController.position.pixels;
    final currentTopChromeMotionEnabled = _isTopChromeMotionEnabled.value;
    final nextStage = pixels > 1500
        ? 3
        : pixels > 920
            ? 2
            : pixels > 320
                ? 1
                : 0;
    var nextTopChromeMotionEnabled = currentTopChromeMotionEnabled;
    if (currentTopChromeMotionEnabled && pixels > 36) {
      nextTopChromeMotionEnabled = false;
    } else if (!currentTopChromeMotionEnabled && pixels < 12) {
      nextTopChromeMotionEnabled = true;
    }
    var nextStickyProgress = 0.0;
    final triggerOffset = _stickyHeaderTriggerOffset;
    if (triggerOffset != null) {
      final transitionStart = triggerOffset - _stickyRevealStartDistance;
      final transitionEnd = triggerOffset + _stickyRevealEndDistance;
      final transitionRange = transitionEnd - transitionStart;
      if (transitionRange > 0) {
        nextStickyProgress =
            ((pixels - transitionStart) / transitionRange).clamp(0.0, 1.0);
      }
    }

    if ((nextStickyProgress - _stickyHeaderProgress.value).abs() > 0.01) {
      _stickyHeaderProgress.value = nextStickyProgress;
    }

    final shouldShowStickyHeader = nextStickyProgress > 0.58;

    if (nextStage != _deferredSectionStage.value) {
      _deferredSectionStage.value = nextStage;
    }
    if (shouldShowStickyHeader != _isStickyHeaderActive.value) {
      _isStickyHeaderActive.value = shouldShowStickyHeader;
    }
    if (nextTopChromeMotionEnabled != currentTopChromeMotionEnabled) {
      _isTopChromeMotionEnabled.value = nextTopChromeMotionEnabled;
    }
  }

  /// Runs on cold start, app resume, and every live service-status event
  /// (enabled or disabled): at most once per session
  /// (_locationPromptShownThisSession), reset whenever the service comes
  /// back on so a later disable can prompt again.
  ///
  /// Two outcomes, checked in order:
  ///   1. Already has a saved address, complete or not — nothing to do.
  ///      Completing House No./Building for an address that was only ever
  ///      reverse-geocoded (never has that filled in) is no longer forced
  ///      here at every app open; that used to block onboarding on a full
  ///      screen with no way out. It's handled instead at checkout — see
  ///      CartBottomBar's address-completeness gate in cart_bottom_bar.dart
  ///      — the one moment it actually blocks something (placing an
  ///      order), rather than blocking browsing the app.
  ///   2. No saved address at all — the original location-enable/
  ///      auto-detect sheet, mandatory (they can't order without an
  ///      address at all). When permission is already granted and service
  ///      is already on, it's told to auto-trigger detection the moment it
  ///      opens instead of waiting for an "Enable" tap — the customer
  ///      still sees the sheet and its spinner/status text either way.
  ///      Pressing Enable saves the address and closes the sheet straight
  ///      into the app — no follow-up completion screen — the customer
  ///      only ever sees that at checkout if they still haven't filled in
  ///      House No./Building by then.
  /// Runs the location and name onboarding checks in sequence — never
  /// concurrently, so their dialogs/sheets can't stack on top of each
  /// other. Every re-entry point (cold start, login while already on
  /// Home, app resume) should call this instead of the two check
  /// functions directly, so location always gets first look and name is
  /// only checked once it's done with whatever it needed to show.
  Future<void> _maybeShowOnboardingPrompts() async {
    await _maybeShowLocationPrompt();
    if (mounted) unawaited(_maybeShowNamePrompt());
  }

  Future<void> _maybeShowLocationPrompt() async {
    if (!mounted || _locationPromptShownThisSession || _locationPromptInFlight) {
      return;
    }
    // Checked synchronously, before the flag below — HomeScreen can be
    // built (and this function's very first, initState-triggered call can
    // run) before login completes, since it's part of AppShell's
    // always-mounted root. If that first call burned the one-shot flag
    // regardless of outcome, a customer who wasn't logged in yet at that
    // moment would never get checked again after actually logging in —
    // this function is one-shot per session specifically to prevent
    // re-showing, not to silently give up the one time it happened to run
    // too early. The real post-login check now comes from the
    // authStateProvider listener set up in initState instead.
    if (ref.read(authStateProvider) is! AuthAuthenticated) return;
    // Set this BEFORE any `await` below, not after — the live
    // service-status-stream listener (see the getServiceStatusStream
    // subscription above) can call this again while an earlier call is
    // still mid-flight (e.g. awaiting the address list, or awaiting the
    // sheet's own success delay). If the flag were only set after those
    // awaits, as it used to be, two near-simultaneous calls could both
    // pass the guard above before either one set it, and each would push
    // its own screen — the sheet from the first call still animating
    // closed (or still sitting there needing a manual swipe-down) while
    // the address-completion screen from the second call appears on top
    // of it. Reported bug: "detect complete then that [sheet] should not
    // come" — a second call slipping through this exact gap.
    _locationPromptShownThisSession = true;
    _locationPromptInFlight = true;
    try {
      final addresses = await ref.read(addressProvider.future);

      // Any address at all — even one still missing House No./Building —
      // is enough to let the customer keep browsing. Completing it is
      // handled at checkout now, not here.
      if (addresses.isNotEmpty) {
        return;
      }

      final shouldShow =
          await ref.read(locationPromptShouldShowProvider.future);
      if (!mounted || !shouldShow) return;

      final permission = await Geolocator.checkPermission();
      final permissionGranted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      final serviceEnabled =
          permissionGranted && await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;

      // Result intentionally unused — Enable saves the address and closes
      // the sheet straight back into the app now; completing House
      // No./Building for it happens at checkout instead (see the doc
      // comment above), not with a follow-up forced screen here.
      await showLocationPromptSheet(
        context,
        autoTrigger: permissionGranted && serviceEnabled,
        mandatory: true,
      );
    } catch (_) {
      // Non-critical — silently ignore
    } finally {
      _locationPromptInFlight = false;
    }
  }

  /// Prompts for a name once per cold start when the logged-in user's
  /// profile doesn't have one yet — OTP-only signup never asks for a name,
  /// so this is the one place that eventually collects it. Dismissing
  /// without saving just means it asks again on the next app open, since
  /// the gate is re-derived fresh from the profile each time, not a
  /// one-shot "already asked" flag.
  ///
  /// Deliberately checks `profileProvider` (a live GET /users/me), NOT
  /// `currentUserProvider` — the latter is the cached/JWT-derived auth
  /// identity, and the access-token JWT never carries a `name` claim at
  /// all. Whenever that cache is empty (fresh install, cleared app data,
  /// or just a restore that fell through to decoding the JWT) the session
  /// gets rebuilt with name always null regardless of what's actually
  /// saved server-side, which made this dialog reappear for users who'd
  /// already provided a name. The profile fetch is the actual source of
  /// truth for this field.
  Future<void> _maybeShowNamePrompt() async {
    if (!mounted || _namePromptAttemptedThisSession) return;
    try {
      // Home is reachable while browsing as a guest (no auth redirect for
      // this route) — skip entirely rather than fetching a profile that
      // doesn't exist for an anonymous session. Deliberately NOT setting
      // _namePromptAttemptedThisSession before this check: a guest-mode
      // call here must stay a true no-op so a later login (caught by
      // _authStateSub / didChangeAppLifecycleState below) still gets to
      // run this check for real instead of finding it already "attempted".
      if (ref.read(currentUserProvider) == null) return;

      _namePromptAttemptedThisSession = true;
      final profileData = await ref.read(profileProvider.future);
      if (!mounted) return;
      final hasName = (profileData.user.name ?? '').trim().isNotEmpty;
      if (hasName) return;
      await showNamePromptDialog(context, ref);
    } catch (_) {
      // Non-critical — silently ignore (e.g. profile fetch failed offline)
    }
  }

  void _updateStickyHeaderTriggerOffset() {
    if (!_homeScrollController.hasClients) {
      return;
    }

    final searchZoneContext = _topSearchZoneKey.currentContext;
    final mediaQuery = MediaQuery.maybeOf(context);
    if (searchZoneContext == null || mediaQuery == null) {
      return;
    }

    final renderObject = searchZoneContext.findRenderObject();
    if (renderObject case final RenderBox box when box.hasSize) {
      final pixels = _homeScrollController.position.pixels;
      final topOffset = box.localToGlobal(Offset.zero).dy;
      _stickyHeaderTriggerOffset =
          pixels + topOffset + box.size.height - mediaQuery.padding.top;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationServiceStatusSub?.cancel();
    _themeSocketSub.close();
    _sectionSocketSub.close();
    _brandingSocketSub.close();
    _themeRefreshTimerSub.close();
    _authStateSub.close();
    _homeDataSub.close();
    _tabHomeContentSub.close();
    _tabKeySub.close();
    _deferredSectionStage
      ..removeListener(_rebuildStagedSlivers)
      ..dispose();
    _isStickyHeaderActive.dispose();
    _isTopChromeMotionEnabled.dispose();
    _stickyHeaderProgress.dispose();
    _cachedStagedSlivers.dispose();
    _homeScrollController
      ..removeListener(_handleHomeScroll)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshThemeDrivenLayout());
      // Covers the case where the app was only backgrounded (not actually
      // process-killed) while the mandatory name dialog was open or before
      // it ever got a chance to check — resuming without this never
      // re-runs _maybeShowNamePrompt, so a user who backgrounded out of
      // the name step effectively never gets asked again for the rest of
      // that process's life. Reported as: name step "stuck"/skippable.
      //
      // BUG FIX: calling _maybeShowOnboardingPrompts() alone did NOT
      // actually fix that — _maybeShowNamePrompt's own one-shot guard
      // (_namePromptAttemptedThisSession) was never cleared, so this call
      // hit its very first line and returned immediately every time,
      // silently no-op'ing forever after the first attempt. Any interruption
      // during that first attempt (backgrounding mid-fetch, a task-switcher
      // swipe-away that Android happens to resume rather than recreate, a
      // pull-to-refresh) permanently burned the one-shot flag without the
      // dialog ever actually being shown/completed — the strict "must
      // provide a name" rule this dialog exists to enforce silently stopped
      // being enforced for the rest of that app session. Resetting it here
      // makes every resume genuinely re-derive from the profile fresh, per
      // this class's own documented intent (see _maybeShowNamePrompt's doc
      // comment) — a no-op the moment a name is actually on file, so this
      // never re-prompts anyone who's already provided one.
      _namePromptAttemptedThisSession = false;
      unawaited(_maybeShowOnboardingPrompts());
      // The live socket listener (app_bottom_nav.dart) only updates unread
      // state while connected — a notification that arrived while the app
      // was backgrounded (socket disconnected, or delivered as a plain
      // push with the app not running) never refreshed it. Without this,
      // the header bell badge stayed stale until the customer either
      // opened the Notifications tab directly or force-restarted the app.
      ref.invalidate(notificationProvider);
      // Same reasoning for the wallet balance shown in the header pill —
      // an admin credit, refund or cashback landed server-side while
      // backgrounded never reaches the keepAlive walletProvider on its own.
      ref.invalidate(walletProvider);
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
      ..invalidate(bannerProvider)
      ..invalidate(categoryCollectionProvider)
      ..invalidate(homeFeaturedProductsProvider)
      ..invalidate(homeDealsProvider)
      ..invalidate(homeTrendingProductsProvider)
      ..invalidate(tabThemesProvider)
      ..invalidate(selectedTabHomeContentProvider)
      ..invalidate(sectionManifestProvider(activeTabKey))
      ..invalidate(activeSectionManifestProvider);
    _stickyHeaderTriggerOffset = null;
    _stickyHeaderProgress.value = 0;
    await Future.wait<void>(<Future<void>>[
      ref.read(homeProvider.future).then((_) {}),
      _refreshThemeDrivenLayout(),
    ]);
  }

  void _openSearch() {
    context.go(RouteNames.search);
  }

  /// Called immediately when the selected category/tab changes.
  /// Resets all per-tab state so no stale Fresh/Dairy content can remain
  /// visible when the user switches to a different tab (including All).
  void _onTabChanged() {
    // Scroll back to top so the header is visible for the new tab.
    if (_homeScrollController.hasClients) {
      _homeScrollController.jumpTo(0);
    }

    // Reset deferred section stage so old-tab sections aren't shown.
    if (_deferredSectionStage.value != 0) {
      _deferredSectionStage.value = 0;
    }
    _lastRenderedStage = -1;
    _cachedStagedSlivers.value = const <Widget>[];

    // Reset sticky header so it recalculates for the new tab layout.
    _stickyHeaderTriggerOffset = null;
    if (_stickyHeaderProgress.value != 0) {
      _stickyHeaderProgress.value = 0;
    }
    if (_isStickyHeaderActive.value) {
      _isStickyHeaderActive.value = false;
    }
    if (!_isTopChromeMotionEnabled.value) {
      _isTopChromeMotionEnabled.value = true;
    }

    // Clear managed tab content immediately — new content will arrive via
    // _tabHomeContentSub once the new tab's provider resolves.
    _clearTabContentCache();

    // Recalculate the sticky trigger offset after the new tab layout renders.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateStickyHeaderTriggerOffset();
        _handleHomeScroll();
      }
    });
  }

  void _recomputeHomeData(HomeScreenData data) {
    final sorted = data.categories
        // BUNDLE categories are promo-only groupings surfaced via a banner
        // deep-link — never shown in the home category strip.
        .where((category) => category.isActive && !category.isBundle)
        .toList(growable: false)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final parents = _buildParentCategories(sorted);
    final staged = parents.take(6).toList(growable: false);
    final priority = staged.take(3).toList(growable: false);
    final deferred = staged.skip(3).toList(growable: false);
    final bannerCards = _buildBannerCarouselCards(data.banners);
    final featuredPool = _buildFeaturedPool(
      managedFeaturedProducts: _managedFeaturedProducts,
      homeFeaturedProducts: data.featuredProducts,
    );

    // PHASE 2B: Mutate fields directly without setState. These fields only
    // feed _buildStagedSlivers → _cachedStagedSlivers (ValueNotifier), so no
    // full-tree rebuild is required. The ValueNotifier update below triggers
    // only the ValueListenableBuilder that wraps the staged section area.
    _stagedCategories = staged;
    _priorityCategories = priority;
    _deferredCategories = deferred;
    _banners = data.banners;
    _homeFeaturedProducts = data.featuredProducts;
    _bannerCarouselCards = bannerCards;
    _featuredPool = featuredPool;
    _refreshStagedSliversCache();
    _ensurePurchaseLimitsLoaded(data.featuredProducts);
  }

  void _recomputeTabContent(TabHomeContentResponse content) {
    final seasonalProducts = content.seasonalProducts
        .where((product) => product.inStock)
        .toList(growable: false);
    final featuredProducts = content.featuredProducts
        .where((product) => product.inStock)
        .toList(growable: false);
    final trendingProducts = content.trendingProducts
        .where((product) => product.inStock)
        .toList(growable: false);
    final categorySections = content.categorySections
        .where((section) => section.products.isNotEmpty)
        .toList(growable: false);
    final featuredPool = _buildFeaturedPool(
      managedFeaturedProducts: featuredProducts,
      homeFeaturedProducts: _homeFeaturedProducts,
    );

    // PHASE 2B: Mutate fields without setState — only update ValueNotifier.
    _managedSeasonalProducts = seasonalProducts;
    _managedFeaturedProducts = featuredProducts;
    _managedTrendingProducts = trendingProducts;
    _managedCategorySections = categorySections;
    _featuredPool = featuredPool;
    _refreshStagedSliversCache();
    _ensurePurchaseLimitsLoaded(<ProductEntity>[
      ...seasonalProducts,
      ...featuredProducts,
      ...trendingProducts,
      for (final section in categorySections) ...section.products,
    ]);
  }

  // Piggybacks on the home/tab-content fetches that are already happening —
  // no extra per-card network call. Cheap no-op for any product already
  // known.
  void _ensurePurchaseLimitsLoaded(List<ProductEntity> products) {
    if (products.isEmpty) {
      return;
    }
    ref.read(purchaseLimitsNotifierProvider.notifier).ensureLoaded(
          products.map((product) => product.id).toSet().toList(),
        );
  }

  void _clearTabContentCache() {
    final featuredPool = _buildFeaturedPool(
      managedFeaturedProducts: const <ProductEntity>[],
      homeFeaturedProducts: _homeFeaturedProducts,
    );

    // PHASE 2B: Mutate fields without setState — only update ValueNotifier.
    _managedSeasonalProducts = const <ProductEntity>[];
    _managedFeaturedProducts = const <ProductEntity>[];
    _managedTrendingProducts = const <ProductEntity>[];
    _managedCategorySections = const <TabCategorySection>[];
    _featuredPool = featuredPool;
    _refreshStagedSliversCache();
  }

  List<ProductEntity> _buildFeaturedPool({
    required List<ProductEntity> managedFeaturedProducts,
    required List<ProductEntity> homeFeaturedProducts,
  }) {
    final source = managedFeaturedProducts.isNotEmpty
        ? managedFeaturedProducts
        : homeFeaturedProducts;
    return _filterProducts(
      source.where((product) => product.inStock).toList(growable: false),
      null,
    );
  }

  void _refreshStagedSliversCache() {
    final stage = _deferredSectionStage.value;
    _lastRenderedStage = stage;
    _cachedStagedSlivers.value = _buildStagedSlivers(stage);
  }

  void _rebuildStagedSlivers() {
    final stage = _deferredSectionStage.value;
    if (stage == _lastRenderedStage) {
      return;
    }

    _lastRenderedStage = stage;
    _cachedStagedSlivers.value = _buildStagedSlivers(stage);
  }

  List<Widget> _buildStagedSlivers(int stage) {
    if (_stagedCategories.isEmpty || stage < 2) {
      return const <Widget>[];
    }

    final slivers = <Widget>[];
    var bannerInserted = false;
    final stagedCategoryList = <CategoryEntity>[
      if (stage >= 2) ..._priorityCategories,
      if (stage >= 3) ..._deferredCategories,
    ];

    // PHASE 4B: Stagger category section activations.
    // Each section gets an index-proportional delay so their provider fetches
    // do not all fire simultaneously at the stage-threshold crossing.
    // Index 0 activates immediately; subsequent sections add 80ms each.
    var catIndex = 0;

    for (final cat in stagedCategoryList) {
      final normalizedName = cat.name.trim().toLowerCase();
      final shouldInsertBannerBeforeCategory = !bannerInserted &&
          _banners.isNotEmpty &&
          _bannerCarouselCards.isNotEmpty &&
          (normalizedName.contains('bakery') ||
              normalizedName.contains('bread'));

      slivers.add(
        _StagedCategorySection(
          key: ValueKey<String>('staged_cat_${cat.id}_$stage'),
          category: cat,
          showBannerAbove: shouldInsertBannerBeforeCategory,
          bannerCards: _bannerCarouselCards,
          // PHASE 4B: 80ms stagger per section index.
          activationDelay: Duration(milliseconds: catIndex * 80),
        ),
      );

      catIndex++;

      if (shouldInsertBannerBeforeCategory) {
        bannerInserted = true;
      }
    }

    return slivers;
  }

  @override
  Widget build(BuildContext context) {
    final topBarTheme = TopBarTheme(
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
    final searchZoneTheme = SearchZoneTheme(
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
    final activeTabKey = ref.watch(activeTabKeyProvider);
    final manifestIsLoading = ref.watch(
      sectionManifestProvider(activeTabKey).select(
        (manifestAsync) => manifestAsync.isLoading,
      ),
    );
    final manifestIsEmpty = ref.watch(
      activeSectionManifestProvider.select(
        (manifest) => manifest.sections.isEmpty,
      ),
    );
    // Show skeleton sections ONLY while the manifest is actively loading and
    // we have no cached content yet.  Never render old summer/campaign
    // hardcoded widgets as a loading fallback.
    final showSkeletonSections = manifestIsEmpty && manifestIsLoading;
    final showCategoryTabs = ref.watch(
      activeTabThemeProvider.select(
        (theme) => theme.sections.categoryTabs.visible,
      ),
    );
    // Independent category-tab background — falls back to search zone color
    // for themes that don't have it set (backward compatible).
    final categoryTabsBgColor = ref.watch(
      activeTabThemeProvider.select(
        (theme) =>
            theme.sections.categoryTabs.backgroundColor ??
            theme.sections.searchZone.backgroundColor,
      ),
    );
    final homeAsync = ref.watch(homeProvider);
    final deliveryEtaMinutes = ref.watch(
      tabThemesProvider.select(
        (tabThemesAsync) => tabThemesAsync.asData?.value.deliveryEtaMinutes,
      ),
    );
    final topInset = MediaQuery.paddingOf(context).top;

    return ValueListenableBuilder<bool>(
      valueListenable: _isStickyHeaderActive,
      builder: (context, isStickyHeaderActive, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: isStickyHeaderActive
              ? const SystemUiOverlayStyle(
                  statusBarIconBrightness: Brightness.dark,
                  statusBarBrightness: Brightness.light,
                  systemNavigationBarIconBrightness: Brightness.dark,
                )
              : const SystemUiOverlayStyle(
                  statusBarIconBrightness: Brightness.dark,
                  statusBarBrightness: Brightness.light,
                  systemNavigationBarIconBrightness: Brightness.dark,
                ),
          child: child!,
        );
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: homeAsync.when(
          loading: () => const _HomeLoadingView(),
          error: (error, stackTrace) => _HomeErrorView(onRetry: _refresh),
          data: (_) {
            if (_stickyHeaderTriggerOffset == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _updateStickyHeaderTriggerOffset();
                  _handleHomeScroll();
                }
              });
            }
            return SafeArea(
              top: false,
              bottom: false,
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.warmOrangeDark,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: CustomScrollView(
                        controller: _homeScrollController,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: <Widget>[
                          SliverToBoxAdapter(
                            child: ValueListenableBuilder<bool>(
                              valueListenable: _isTopChromeMotionEnabled,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Consumer(
                                    builder: (context, ref, _) {
                                      final currentUser = ref.watch(
                                        currentUserProvider,
                                      );
                                      final addresses = currentUser == null
                                          ? null
                                          : ref
                                              .watch(addressProvider)
                                              .asData
                                              ?.value;
                                      final hasTrackingBanner = ref
                                          .watch(orderTrackingBannerProvider)
                                          .isNotEmpty;
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          const OrderTrackingTopBanner(),
                                          HomeHeader(
                                            addressText: resolveAddressLabel(
                                              isLoggedIn: currentUser != null,
                                              addresses: addresses,
                                            ),
                                            onAddressTap: () =>
                                                showAddressSheet(context),
                                            onNotificationTap: () => context
                                                .go(RouteNames.notifications),
                                            onWalletTap: () =>
                                                context.go(RouteNames.wallet),
                                            topBarTheme: topBarTheme,
                                            searchZoneColor: searchZoneTheme
                                                .backgroundColor,
                                            deliveryEtaMinutes:
                                                deliveryEtaMinutes,
                                            topPaddingOverride:
                                                hasTrackingBanner ? 0 : null,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                              builder: (
                                context,
                                isTopChromeMotionEnabled,
                                child,
                              ) {
                                return ColoredBox(
                                  color: topBarTheme.backgroundColor,
                                  child: TickerMode(
                                    enabled: isTopChromeMotionEnabled,
                                    child: child!,
                                  ),
                                );
                              },
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: ValueListenableBuilder<bool>(
                              valueListenable: _isTopChromeMotionEnabled,
                              builder: (
                                context,
                                isTopChromeMotionEnabled,
                                _,
                              ) {
                                return Container(
                                  key: _topSearchZoneKey,
                                  color: Colors.transparent,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      // Search zone — uses searchZone.backgroundColor
                                      ColoredBox(
                                        color: searchZoneTheme.backgroundColor,
                                        child: TickerMode(
                                          enabled: isTopChromeMotionEnabled,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              const SizedBox.shrink(),
                                              HomeSearchBar(
                                                onSearchTap: _openSearch,
                                                animateHints:
                                                    isTopChromeMotionEnabled,
                                                searchTheme: searchZoneTheme,
                                                outerPadding:
                                                    EdgeInsets.fromLTRB(
                                                  12.w,
                                                  0,
                                                  12.w,
                                                  10.h,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Store-closed banner — sits directly
                                      // under the search bar (above category
                                      // tabs) so it reads as a status line
                                      // right below the primary nav action,
                                      // not buried after tab browsing.
                                      const StoreClosedBanner(),
                                      // Category tabs — independent backgroundColor
                                      // (falls back to searchZone color for legacy themes)
                                      if (showCategoryTabs) ...<Widget>[
                                        ColoredBox(
                                          color: categoryTabsBgColor,
                                          child: TickerMode(
                                            enabled: isTopChromeMotionEnabled,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Gap(4.h),
                                                const CategoryTabsRow(),
                                                Gap(6.h),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ] else
                                        ColoredBox(
                                          color:
                                              searchZoneTheme.backgroundColor,
                                          child: Gap(10.h),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          // PHASE 1 FIX: Never render old summer/campaign
                          // hardcoded widgets as a loading fallback.
                          // Show skeleton while manifest loads; show
                          // DynamicHomeSections once manifest arrives (even if
                          // empty — an empty manifest means the dashboard
                          // intentionally has no sections).
                          if (showSkeletonSections)
                            const SliverToBoxAdapter(
                              child: _HomeSectionsSkeleton(),
                            )
                          else
                            DynamicHomeSections(
                              key: ValueKey<String>(activeTabKey),
                            ),
                          SliverToBoxAdapter(child: Gap(0)),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ValueListenableBuilder<double>(
                        valueListenable: _stickyHeaderProgress,
                        child: _StickySearchOverlayChrome(
                          topInset: topInset,
                          onSearchTap: _openSearch,
                          searchTheme: searchZoneTheme,
                          showCategoryTabs: showCategoryTabs,
                        ),
                        builder: (context, progress, child) {
                          return _StickySearchOverlay(
                            progress: progress,
                            topInset: topInset,
                            showCategoryTabs: showCategoryTabs,
                            child: child!,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<CategoryEntity> _buildParentCategories(
    List<CategoryEntity> categories,
  ) {
    final parents = categories
        .where((category) => category.isParent && category.productCount > 0)
        .toList(growable: false);
    return parents.isNotEmpty ? parents : categories.take(8).toList();
  }

  List<ProductEntity> _filterProducts(
    List<ProductEntity> products,
    CategoryEntity? category,
  ) {
    if (category == null) {
      return products;
    }

    final filtered = products.where((product) {
      if (product.categoryId == category.id) {
        return true;
      }

      return (product.categoryName ?? '').trim().toLowerCase() ==
          category.name.trim().toLowerCase();
    }).toList(growable: false);
    return filtered.isNotEmpty ? filtered : products;
  }

  List<_HomePromoData> _buildBannerCarouselCards(List<BannerEntity> banners) {
    final validBanners = banners.where(
      (banner) => _hasRenderableMediaUrl(banner.imageUrl),
    );

    return validBanners
        .map(
          (banner) => _HomePromoData(
            eyebrow: (banner.title ?? '').trim(),
            headline: (banner.subtitle ?? '').trim(),
            supporting: (banner.linkType).trim(),
            cta: 'Explore',
            imageUrl: banner.imageUrl,
            routePath: _routePathForBanner(banner),
          ),
        )
        .toList(growable: false);
  }

  String? _routePathForBanner(BannerEntity banner) {
    final linkValue = banner.linkValue;
    if (linkValue == null || linkValue.isEmpty) {
      return null;
    }

    final lowerType = banner.linkType.toLowerCase();
    if (lowerType.contains('product')) {
      return '/product/$linkValue';
    }
    if (lowerType.contains('category')) {
      return '/categories/$linkValue/products';
    }
    return null;
  }
}

class _StickySearchOverlay extends StatelessWidget {
  const _StickySearchOverlay({
    required this.child,
    required this.progress,
    required this.topInset,
    required this.showCategoryTabs,
  });

  final Widget child;
  final double progress;
  final double topInset;
  final bool showCategoryTabs;

  double get _searchTopPadding => 8.h;
  double get _betweenSections => 6.h;
  double get _tabsHeight => showCategoryTabs ? 44.h : 0;
  double get _tabsBlockSpacing => showCategoryTabs ? _betweenSections : 0;
  double get _hiddenTabsBottomSpacing => showCategoryTabs ? 0 : 12.h;
  double get _bottomPadding => 6.h;
  double get _headerExtent =>
      topInset +
      _searchTopPadding +
      56.h +
      _tabsBlockSpacing +
      _tabsHeight +
      _hiddenTabsBottomSpacing +
      _bottomPadding;

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    if (clampedProgress <= 0) {
      return const SizedBox.shrink();
    }

    // PHASE 3A: Threshold-based states instead of per-pixel animated values.
    //
    // Previous code:
    //   • backgroundProgress = Curves.easeOutCubic.transform(clampedProgress)
    //     → Color.lerp on EVERY scroll tick → DecoratedBox paint on every tick
    //   • contentProgress → Opacity(opacity: ...) → saveLayer on raster thread
    //     on every frame while 0 < opacity < 1
    //   • boxShadow alpha = 0.05 * backgroundProgress → new Paint object every tick
    //
    // New approach:
    //   • Background and border snap to opaque/transparent at a single threshold
    //     (progress ≥ 0.5) using const Colors — no per-tick Color.lerp
    //   • Content uses AnimatedOpacity which does NOT create a saveLayer when the
    //     value is exactly 0.0 or 1.0, only during the brief transition
    //   • Shadow is const and always the same value — no per-tick alpha calculation
    //   • Translate offset snaps: visible (0) or hidden (−14.h) at threshold
    //
    // The visual result is functionally identical: the overlay fades in as the
    // user scrolls past the search zone, with a white background and shadow.

    final bool isVisible = clampedProgress >= 0.5;
    final double translateY = isVisible ? 0.0 : -14.h;

    return IgnorePointer(
      ignoring: clampedProgress < 0.82,
      child: RepaintBoundary(
        child: SizedBox(
          height: _headerExtent,
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: DecoratedBox(
              // PHASE 3A: Stable const decoration — no per-tick Color.lerp or
              // dynamic alpha. The background and border simply appear/disappear
              // at the isVisible threshold.
              decoration: isVisible
                  ? const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE8E8E8)),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          // PHASE 3D: Reduced blur (12 → 6) and stable alpha.
                          // blurRadius 18 with alpha 0.05 ≈ blurRadius 6 with
                          // alpha 0.08 visually; far cheaper to rasterize.
                          color: Color(0x14000000), // ~8% black
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    )
                  : const BoxDecoration(),
              // PHASE 3A: AnimatedOpacity instead of Opacity.
              // AnimatedOpacity skips saveLayer entirely when value == 1.0,
              // which is the steady state. The brief 150ms fade-in uses an
              // internal animation controller, not the scroll listener.
              child: AnimatedOpacity(
                opacity: isVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StickySearchOverlayChrome extends StatelessWidget {
  const _StickySearchOverlayChrome({
    required this.topInset,
    required this.onSearchTap,
    required this.showCategoryTabs,
    this.searchTheme,
  });

  final double topInset;
  final VoidCallback onSearchTap;
  final bool showCategoryTabs;
  final SearchZoneTheme? searchTheme;

  double get _searchTopPadding => 8.h;
  double get _betweenSections => 4.h;
  double get _bottomPadding => 6.h;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(height: topInset),
        HomeSearchBar(
          onSearchTap: onSearchTap,
          animateHints: false,
          searchTheme: searchTheme,
          outerPadding: EdgeInsets.fromLTRB(12.w, _searchTopPadding, 12.w, 0),
        ),
        if (showCategoryTabs) ...<Widget>[
          Gap(_betweenSections),
          const CategoryTabsRow(textOnly: true),
        ] else
          Gap(12.h),
        Gap(_bottomPadding),
      ],
    );
  }
}

class _HeroPromoCarousel extends StatefulWidget {
  const _HeroPromoCarousel({required this.cards});

  final List<_HomePromoData> cards;

  @override
  State<_HeroPromoCarousel> createState() => _HeroPromoCarouselState();
}

class _HeroPromoCarouselState extends State<_HeroPromoCarousel> {
  static const int _loopSeedMultiplier = 1000;

  late final PageController _pageController;
  Timer? _autoPlayTimer;
  int _virtualPage = 0;

  @override
  void initState() {
    super.initState();
    _virtualPage = _startingVirtualPage(widget.cards.length);
    _pageController = PageController(
      viewportFraction: 0.88,
      initialPage: _virtualPage,
    );
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant _HeroPromoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cards.length != widget.cards.length) {
      _autoPlayTimer?.cancel();
      _virtualPage = _startingVirtualPage(widget.cards.length);
      _jumpToVirtualPage(_virtualPage);
      _startAutoPlay();
    }
  }

  int _startingVirtualPage(int length) {
    if (length <= 1) {
      return 0;
    }
    return length * _loopSeedMultiplier;
  }

  int _effectiveIndex(int page) {
    final length = widget.cards.length;
    if (length == 0) {
      return 0;
    }
    final remainder = page % length;
    return remainder < 0 ? remainder + length : remainder;
  }

  void _jumpToVirtualPage(int page) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }
      _pageController.jumpToPage(page);
    });
  }

  void _startAutoPlay() {
    if (widget.cards.length <= 1) {
      return;
    }
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }
      final nextPage = _virtualPage + 1;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: SizedBox(
            height: 198.h,
            child: PageView.builder(
              controller: _pageController,
              padEnds: true,
              clipBehavior: Clip.none,
              itemCount: widget.cards.length <= 1 ? widget.cards.length : null,
              onPageChanged: (value) {
                _virtualPage = value;
              },
              itemBuilder: (context, index) {
                final card = widget.cards[_effectiveIndex(index)];
                return Padding(
                  padding: EdgeInsets.fromLTRB(6.w, 4.h, 6.w, 6.h),
                  child: _HeroPromoCard(card: card),
                );
              },
            ),
          ),
        ),
        Gap(2.h),
      ],
    );
  }
}

class _HeroPromoCard extends StatelessWidget {
  const _HeroPromoCard({required this.card});

  final _HomePromoData card;

  @override
  Widget build(BuildContext context) {
    final optimizedImage = ApiConstants.optimizedMedia(
      card.imageUrl,
      profile: CustomerImageProfile.banner,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        // PHASE 3D: Reduced blur radius 12→4 and lower alpha (0x0C→0x09).
        // The card is inside a PageView with ClipRRect so heavy shadow blur
        // is invisible anyway; a tight 4px shadow preserves the lifted look.
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: card.routePath == null
                ? null
                : () => context.push(card.routePath!),
            child: SizedBox.expand(
              child: card.imageUrl == null
                  ? const _FallbackHeroArt()
                  : AppImage(
                      imageUrl: optimizedImage.url ?? card.imageUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: optimizedImage.memCacheWidth,
                      memCacheHeight: optimizedImage.memCacheHeight,
                      filterQuality: FilterQuality.high,
                      placeholder: const _FallbackHeroArt(),
                      errorWidget: const _FallbackHeroArt(),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackHeroArt extends StatelessWidget {
  const _FallbackHeroArt();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF3FBD7),
      child: Center(
        child: PhosphorIcon(
          PhosphorIcons.imageSquareDuotone,
          size: 40.sp,
          color: const Color(0xFF9BA56A),
        ),
      ),
    );
  }
}

bool _hasRenderableMediaUrl(String? rawUrl) {
  final value = ApiConstants.resolveMediaUrl(rawUrl)?.trim();
  if (value == null || value.isEmpty || value.toLowerCase() == 'null') {
    return false;
  }
  if (value.startsWith('data:')) {
    return true;
  }

  final uri = Uri.tryParse(value);
  return uri != null && uri.hasScheme && uri.host.isNotEmpty;
}

String _fancyCategoryName(String raw) {
  final n = raw.trim().toLowerCase();
  if (n.contains('dairy') || n.contains('egg')) {
    return '🥛 Dairy & Breakfast Essentials';
  }
  if (n.contains('fruit') || n.contains('vegetable')) {
    return '🥬 Fresh Fruits & Veggies';
  }
  if (n.contains('snack')) {
    return '🍿 Snacks & Munchies';
  }
  if (n.contains('drink') || n.contains('beverage') || n.contains('juice')) {
    return '🥤 Cold Drinks & Juices';
  }
  if (n.contains('bakery') || n.contains('bread')) {
    return '🍞 Bakery & Bread';
  }
  if (n.contains('oil') || n.contains('ghee') || n.contains('masala')) {
    return '🫗 Oils, Ghee & Masala';
  }
  if (n.contains('clean') || n.contains('household')) {
    return '🧹 Cleaning & Household';
  }
  if (n.contains('beauty') || n.contains('personal')) {
    return '✨ Beauty & Personal Care';
  }
  return '🛒 $raw';
}

class _HomeSectionHeader extends StatelessWidget {
  const _HomeSectionHeader({
    required this.title,
    this.actionLabel,
    this.onTap,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.h2.copyWith(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (actionLabel != null && onTap != null)
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.warmOrangeDark,
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: AppTextStyles.buttonMedium.copyWith(
                color: AppColors.warmOrangeDark,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Category Product Section — 3×2 grid ─────────────────

class _CategoryProductSection extends StatelessWidget {
  const _CategoryProductSection({
    required this.title,
    required this.categoryId,
    required this.products,
  });

  final String title;
  final String categoryId;
  final List<ProductEntity> products;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 22.w),
          child: _HomeSectionHeader(
            title: title,
            actionLabel: 'see all',
            onTap: () => context.push('/categories/$categoryId/products'),
          ),
        ),
        Gap(10.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: RepaintBoundary(
            child: _ThreeColumnProductGrid<ProductEntity>(
              items: products.take(6).toList(growable: false),
              itemBuilder: (product) => ProductCard(
                product: product,
                width: _threeColumnCardWidth(context),
                style: ProductCardStyle.grid,
                showWishlist: true,
                onTap: () => context.push('/products/${product.id}'),
                onOptionsTap: () => showProductOptionsSheet(context, product),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThreeColumnProductGrid<T> extends StatelessWidget {
  const _ThreeColumnProductGrid({
    required this.items,
    required this.itemBuilder,
  });

  final List<T> items;
  final Widget Function(T item) itemBuilder;

  // PHASE 2A: Fixed row height replaces IntrinsicHeight to eliminate the
  // double-layout pass. The value is derived from the ProductCard grid design:
  //   image area  ≈ cardWidth × 0.84 (scaled)
  //   below-box   ≈ price + discount + name(2 lines) + rating + delivery
  //              ≈ 130 logical units at typical density
  // Using a LayoutBuilder so we derive the actual card width at paint time
  // and set a row height that matches the tallest possible card without a
  // second layout pass.
  static double _rowHeight(double availableWidth) {
    // Three columns with two 10-unit gaps and 32 units total horizontal padding
    // (16 each side) — matching _threeColumnCardWidth logic.
    const double columnGapTotal = 20.0; // 10 × 2 gaps
    const double sidePadTotal = 32.0;   // 16 × 2 sides
    final double cardPx = (availableWidth - columnGapTotal - sidePadTotal) / 3;
    final double imageHeight = cardPx * 0.84;
    // Below-box: unit row(~28) + divider(1) + price(~22) + discount(~16) +
    // name 2-lines(~34) + rating(~16) + delivery(~16) + gaps(~12) = ~145
    const double belowBox = 145.0;
    return imageHeight + belowBox;
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final rows = <List<T>>[];
    for (var index = 0; index < items.length; index += 3) {
      final nextIndex = index + 3 < items.length ? index + 3 : items.length;
      rows.add(items.sublist(index, nextIndex));
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double rowH = _rowHeight(constraints.maxWidth);
        return Column(
          children: <Widget>[
            for (var rowIndex = 0;
                rowIndex < rows.length;
                rowIndex++) ...<Widget>[
              if (rowIndex > 0) Gap(12.h),
              // Fixed-height row: no IntrinsicHeight, single layout pass.
              SizedBox(
                height: rowH,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (var columnIndex = 0;
                        columnIndex < 3;
                        columnIndex++) ...<Widget>[
                      Expanded(
                        child: columnIndex < rows[rowIndex].length
                            ? RepaintBoundary(
                                child:
                                    itemBuilder(rows[rowIndex][columnIndex]),
                              )
                            : const SizedBox.shrink(),
                      ),
                      if (columnIndex < 2) Gap(10.w),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Staged category section — PHASE 2E / PHASE 4B ─────────────────────────
//
// Dedicated ConsumerWidget so only this individual section rebuilds when its
// homeCategoryProductsProvider resolves. Previously this was an inline
// Consumer closure inside _buildStagedSlivers which captured the whole
// sliver list closure on every rebuild.
//
// PHASE 4B: The activationDelay parameter staggers the first provider watch so
// all category sections don't fire their network requests simultaneously at the
// scroll-threshold crossing. Index 0 activates immediately; each subsequent
// section adds 80ms.

class _StagedCategorySection extends ConsumerStatefulWidget {
  const _StagedCategorySection({
    required this.category,
    required this.showBannerAbove,
    required this.bannerCards,
    this.activationDelay = Duration.zero,
    super.key,
  });

  final CategoryEntity category;
  final bool showBannerAbove;
  final List<_HomePromoData> bannerCards;
  final Duration activationDelay;

  @override
  ConsumerState<_StagedCategorySection> createState() =>
      _StagedCategorySectionState();
}

class _StagedCategorySectionState
    extends ConsumerState<_StagedCategorySection> {
  bool _activated = false;

  @override
  void initState() {
    super.initState();
    if (widget.activationDelay == Duration.zero) {
      _activated = true;
    } else {
      // Schedule activation after the stagger delay.
      Future<void>.delayed(widget.activationDelay).then((_) {
        if (mounted) setState(() => _activated = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // While waiting for the stagger delay, show nothing (section is
    // below the fold anyway — the scroll has just reached the threshold).
    if (!_activated) return const SizedBox.shrink();

    final catProducts =
        ref.watch(homeCategoryProductsProvider(widget.category.id)).asData?.value;
    if (catProducts == null || catProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    final renderable = catProducts
        .where((product) => product.inStock)
        .toList(growable: false);
    if (renderable.length < 2) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.showBannerAbove && widget.bannerCards.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(0, 6.h, 0, 6.h),
            child: RepaintBoundary(
              child: _HeroPromoCarousel(cards: widget.bannerCards),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(top: 6.h),
          child: RepaintBoundary(
            child: _CategoryProductSection(
              title: _fancyCategoryName(widget.category.name),
              categoryId: widget.category.id,
              products: renderable.take(6).toList(growable: false),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Dashed line painter ─────────────────────────────────

class _HomePromoData {
  const _HomePromoData({
    required this.eyebrow,
    required this.headline,
    required this.supporting,
    required this.cta,
    required this.imageUrl,
    required this.routePath,
  });

  final String eyebrow;
  final String headline;
  final String supporting;
  final String cta;
  final String? imageUrl;
  final String? routePath;
}

class _AddressBottomSheet extends ConsumerWidget {
  const _AddressBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AddressBottomSheet();
  }
}

class _HomeLoadingView extends StatelessWidget {
  const _HomeLoadingView();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      // PERF: Single Shimmer animation controller for all skeleton boxes.
      child: SkeletonShimmerGroup(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(22.w, 12.h, 22.w, 124.h),
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SkeletonLoader(
                          width: 190.w, height: 24.h, radius: 12,
                          useOwnShimmer: false),
                      Gap(8.h),
                      SkeletonLoader(
                          width: 168.w, height: 24.h, radius: 12,
                          useOwnShimmer: false),
                      Gap(12.h),
                      SkeletonLoader(
                          width: 220.w, height: 14.h, radius: 10,
                          useOwnShimmer: false),
                    ],
                  ),
                ),
                Gap(14.w),
                const SkeletonLoader.circular(size: 56, useOwnShimmer: false),
                Gap(10.w),
                const SkeletonLoader.circular(size: 56, useOwnShimmer: false),
              ],
            ),
            Gap(24.h),
            SkeletonLoader(
                width: double.infinity, height: 192.h, radius: 30,
                useOwnShimmer: false),
            Gap(12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SkeletonLoader(
                    width: 24.w, height: 8.h, radius: 99,
                    useOwnShimmer: false),
                Gap(6.w),
                SkeletonLoader(
                    width: 8.w, height: 8.h, radius: 99,
                    useOwnShimmer: false),
                Gap(6.w),
                SkeletonLoader(
                    width: 8.w, height: 8.h, radius: 99,
                    useOwnShimmer: false),
              ],
            ),
            Gap(18.h),
            SizedBox(
              height: 56.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                itemExtentBuilder: (index, _) => _horizontalRailExtent(
                  index,
                  4,
                  124.w,
                  12.w,
                ),
                itemBuilder: (_, __) => SkeletonLoader(
                  width: 124.w,
                  height: 56.h,
                  radius: 18,
                  useOwnShimmer: false,
                ),
              ),
            ),
            Gap(28.h),
            SkeletonLoader(
                width: 180.w, height: 18.h, radius: 12,
                useOwnShimmer: false),
            Gap(14.h),
            SizedBox(
              height: 306.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 2,
                itemExtentBuilder: (index, _) => _horizontalRailExtent(
                  index,
                  2,
                  248.w,
                  16.w,
                ),
                itemBuilder: (_, __) => SkeletonLoader(
                  width: 248.w,
                  height: 306.h,
                  radius: 30,
                  useOwnShimmer: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeErrorView extends StatelessWidget {
  const _HomeErrorView({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ErrorState(
      title: 'Home feed unavailable',
      message: 'We could not load the storefront right now. Try again.',
      onRetry: () => unawaited(onRetry()),
    );
  }
}

/// Skeleton shown inside the scroll view while the section manifest is loading.
/// Replaces old hardcoded summer/campaign fallback widgets so nothing from a
/// previous deployment ever flashes on startup.
class _HomeSectionsSkeleton extends StatelessWidget {
  const _HomeSectionsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(22.w, 8.h, 22.w, 40.h),
      // PERF: Single Shimmer controller for the section skeleton group.
      child: SkeletonShimmerGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Banner skeleton
            SkeletonLoader(
                width: double.infinity, height: 160.h, radius: 24,
                useOwnShimmer: false),
            Gap(16.h),
            // Section header skeleton
            SkeletonLoader(
                width: 160.w, height: 18.h, radius: 10,
                useOwnShimmer: false),
            Gap(12.h),
            // Horizontal product rail skeleton
            SizedBox(
              height: 200.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                itemExtentBuilder: (index, _) => _horizontalRailExtent(
                  index,
                  3,
                  148.w,
                  12.w,
                ),
                itemBuilder: (_, __) => SkeletonLoader(
                  width: 148.w,
                  height: 200.h,
                  radius: 20,
                  useOwnShimmer: false,
                ),
              ),
            ),
            Gap(20.h),
            SkeletonLoader(
                width: 140.w, height: 18.h, radius: 10,
                useOwnShimmer: false),
            Gap(12.h),
            SizedBox(
              height: 200.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                itemExtentBuilder: (index, _) => _horizontalRailExtent(
                  index,
                  3,
                  148.w,
                  12.w,
                ),
                itemBuilder: (_, __) => SkeletonLoader(
                  width: 148.w,
                  height: 200.h,
                  radius: 20,
                  useOwnShimmer: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/core/branding/branding_provider.dart';
import 'package:bakaloo_flutter_app/core/refresh/storefront_refresh_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_provider.dart';
import 'package:bakaloo_flutter_app/core/storefront/storefront_sync.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/location/presentation/providers/guest_storefront_provider.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';
import 'package:bakaloo_flutter_app/shared/utils/address_utils.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/widgets/dynamic_home_sections.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/widgets/order_tracking_top_banner.dart';
import 'package:bakaloo_flutter_app/features/purchase_limits/presentation/providers/purchase_limits_provider.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:bakaloo_flutter_app/routing/app_router.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/shared/widgets/category_tabs_row.dart';
import 'package:bakaloo_flutter_app/shared/widgets/home_header.dart';
import 'package:bakaloo_flutter_app/shared/widgets/home_search_bar.dart';
import 'package:bakaloo_flutter_app/shared/widgets/store_closed_banner.dart';
import 'package:bakaloo_flutter_app/shared/widgets/skeleton_loader.dart';
import 'package:bakaloo_flutter_app/features/location/presentation/providers/location_prompt_provider.dart';
import 'package:bakaloo_flutter_app/features/location/presentation/providers/non_serviceable_location_provider.dart';
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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  // A public storefront has no socket token before sign-in, so Web needs a
  // small polling fallback for dashboard-managed catalogue changes. Signed-in
  // customers still receive the existing socket events immediately; this
  // timer keeps the anonymous browser view current without a page reload.
  static const Duration _webStorefrontRefreshInterval = Duration(seconds: 20);

  late final ScrollController _homeScrollController;
  late final ProviderSubscription<AsyncValue<Map<String, dynamic>>>
      _brandingSocketSub;
  late final ProviderSubscription<AuthState> _authStateSub;
  // Theme/section socket events, the periodic refresh and tab prefetching all
  // live in StorefrontSync / storefrontPrefetchProvider; holding a
  // subscription here just keeps them alive while Home is mounted.
  late final ProviderSubscription<StorefrontSync> _storefrontSyncSub;
  late final ProviderSubscription<void> _storefrontPrefetchSub;
  late final ProviderSubscription<ActiveSections> _sectionsSub;
  Timer? _webStorefrontRefreshTimer;
  // Resets scroll/sticky state when the visible tab changes.
  late final ProviderSubscription<String> _tabKeySub;
  String _activeTabKey = 'all';
  final GlobalKey _topSearchZoneKey = GlobalKey();
  double? _stickyHeaderTriggerOffset;
  final ValueNotifier<double> _stickyHeaderProgress = ValueNotifier<double>(0);
  final ValueNotifier<bool> _isStickyHeaderActive = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isTopChromeMotionEnabled =
      ValueNotifier<bool>(true);
  bool _isRefreshInFlight = false;
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
    _brandingSocketSub = ref.listenManual(
      socketBrandingUpdateStreamProvider,
      (previous, next) {
        next.whenData((event) {
          unawaited(ref.read(brandingProvider.notifier).refresh());
        });
      },
    );
    _storefrontSyncSub = ref.listenManual(storefrontSyncProvider, (_, __) {});
    _storefrontPrefetchSub =
        ref.listenManual(storefrontPrefetchProvider, (_, __) {});
    if (kIsWeb) {
      _webStorefrontRefreshTimer = Timer.periodic(
        _webStorefrontRefreshInterval,
        // A guest has no socket token, so poll. Revalidation is ETag-based and
        // commits in place: an unchanged storefront costs a 304 and NO rebuild
        // (this used to blank the whole screen behind a skeleton every 20s).
        (_) => unawaited(ref.read(storefrontSyncProvider).revalidateActive(
              force: true,
            )),
      );
    }
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
    // Piggyback purchase-limit lookups on the manifest the screen already has
    // (no extra per-card request); a no-op for products already known.
    _sectionsSub = ref.listenManual<ActiveSections>(
      activeSectionsProvider,
      (_, ActiveSections next) => _ensurePurchaseLimitsLoaded(next),
      fireImmediately: true,
    );
    // Listen to the RESOLVED tab (not the raw selection) so resolving the
    // default tab of a freshly loaded store doesn't count as a user switch.
    _activeTabKey = ref.read(activeTabKeyProvider);
    _tabKeySub = ref.listenManual<String>(
      activeTabKeyProvider,
      (previous, next) {
        if (previous == next || next == _activeTabKey) return;
        _activeTabKey = next;
        _onTabChanged();
      },
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
    // The geolocator service-status stream is a native-only capability.
    // Browsers expose location permission on demand and throw when this
    // stream is requested, so Web must not subscribe during home startup.
    if (!kIsWeb) {
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
    }
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
  ///   2. No saved address at all — offer the location-enable/
  ///      auto-detect sheet without blocking browsing. A delivery address
  ///      is still required when the customer reaches checkout. When
  ///      permission is already granted and service
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
    if (!mounted ||
        _locationPromptShownThisSession ||
        _locationPromptInFlight) {
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
        mandatory: false,
      );
      if (mounted && ref.read(nonServiceableLocationProvider)) {
        context.push(RouteNames.locationUnavailable);
      }
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
    _webStorefrontRefreshTimer?.cancel();
    _brandingSocketSub.close();
    _storefrontSyncSub.close();
    _storefrontPrefetchSub.close();
    _sectionsSub.close();
    _authStateSub.close();
    _tabKeySub.close();
    _isStickyHeaderActive.dispose();
    _isTopChromeMotionEnabled.dispose();
    _stickyHeaderProgress.dispose();
    _homeScrollController
      ..removeListener(_handleHomeScroll)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Dashboard changes made while backgrounded: revalidate the visible
      // storefront in place. Content younger than the freshness window costs no
      // request, older content shows immediately and is replaced only if it
      // actually changed — resuming never flashes a skeleton.
      unawaited(ref.read(storefrontSyncProvider).revalidateActive());
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

  /// Pull-to-refresh: force-revalidate the visible theme + tab together, and
  /// re-read the other live storefront feeds (banners, categories, featured).
  /// The current content stays on screen throughout.
  Future<void> _refresh() async {
    if (_isRefreshInFlight) {
      return;
    }
    _isRefreshInFlight = true;
    try {
      refreshStorefrontContent(ref);
      _stickyHeaderTriggerOffset = null;
      _stickyHeaderProgress.value = 0;
      await ref.read(storefrontSyncProvider).revalidateActive(force: true);
    } finally {
      _isRefreshInFlight = false;
    }
  }

  void _openSearch() {
    context.go(RouteNames.search);
  }

  void _ensurePurchaseLimitsLoaded(ActiveSections sections) {
    final Set<String> ids = <String>{
      for (final entry in sections.sections)
        for (final Map<String, dynamic> product in entry.products)
          if (product['id'] != null) product['id'].toString(),
    };
    if (ids.isEmpty) {
      return;
    }
    ref
        .read(purchaseLimitsNotifierProvider.notifier)
        .ensureLoaded(ids.take(60).toList(growable: false));
  }

  /// Called when the visible tab changes: scroll back to the top and reset the
  /// sticky-header state so it recalculates for the new tab's layout. Content
  /// itself is swapped by the scoped section providers — there is no per-tab
  /// state kept here that could linger from the previous tab.
  void _onTabChanged() {
    if (_homeScrollController.hasClients) {
      _homeScrollController.jumpTo(0);
    }

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

    // Recalculate the sticky trigger offset after the new tab layout renders.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateStickyHeaderTriggerOffset();
        _handleHomeScroll();
      }
    });
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
      colorEnabled: ref.watch(
        activeTabThemeProvider
            .select((theme) => theme.sections.topBar.colorEnabled),
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
      colorEnabled: ref.watch(
        activeTabThemeProvider
            .select((theme) => theme.sections.searchZone.colorEnabled),
      ),
    );
    final headerBackgroundImageUrl = ref.watch(
      activeTabThemeProvider.select(
        (theme) => theme.sections.headerBackground.imageUrl,
      ),
    );
    final activeTabKey = ref.watch(activeTabKeyProvider);
    final SectionsStatus sectionsStatus = ref.watch(
      activeSectionsProvider.select((sections) => sections.status),
    );
    final bool sectionsEmpty = ref.watch(
      activeSectionsProvider.select((sections) => sections.isEmpty),
    );
    // Skeleton ONLY for a genuine first load of this (store, shop, mode, tab).
    // Once content is held it stays on screen while a revalidation runs, and a
    // tab switch to an already-loaded tab renders immediately. Never a bundled
    // campaign widget as a loading fallback.
    final showSkeletonSections = sectionsStatus == SectionsStatus.loading;
    final showSectionsUnavailable = sectionsStatus == SectionsStatus.failed ||
        (sectionsStatus == SectionsStatus.ready && sectionsEmpty);
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
    final categoryTabsColorEnabled = ref.watch(
      activeTabThemeProvider
          .select((theme) => theme.sections.categoryTabs.colorEnabled),
    );
    final deliveryEtaMinutes = ref.watch(
      tabThemesProvider.select(
        (tabThemesAsync) => tabThemesAsync.value?.deliveryEtaMinutes,
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
        body: Builder(
          builder: (context) {
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
                      child: Scrollbar(
                        controller: _homeScrollController,
                        // Desktop/web shoppers need a visible, draggable
                        // affordance for the longer manifest-driven home
                        // feed. Native platforms keep their conventional
                        // overlay scrollbar behavior.
                        thumbVisibility: kIsWeb,
                        interactive: kIsWeb,
                        child: CustomScrollView(
                          controller: _homeScrollController,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          slivers: <Widget>[
                            SliverToBoxAdapter(
                              child: Stack(
                                children: <Widget>[
                                  // Shared background image behind the top
                                  // bar + search zone + category tabs block
                                  // below. The Stack sizes itself to that
                                  // Column's natural height, so Positioned.fill
                                  // matches it with no hardcoded height.
                                  if (headerBackgroundImageUrl != null &&
                                      headerBackgroundImageUrl.isNotEmpty)
                                    Positioned.fill(
                                      child: AppImage(
                                        imageUrl: headerBackgroundImageUrl,
                                        memCacheWidth:
                                            MediaQuery.sizeOf(context)
                                                .width
                                                .round(),
                                        memCacheHeight: 900,
                                        fit: BoxFit.cover,
                                        // Any cropping from a shorter-than-image
                                        // device (smaller status bar, tabs
                                        // hidden, etc.) should trim the bottom
                                        // of the image, not the top — the
                                        // delivery-address text sits right at
                                        // the top of this block.
                                        alignment: Alignment.topCenter,
                                      ),
                                    ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      ValueListenableBuilder<bool>(
                                        valueListenable:
                                            _isTopChromeMotionEnabled,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Consumer(
                                              builder: (context, ref, _) {
                                                final currentUser = ref.watch(
                                                  currentUserProvider,
                                                );
                                                final addresses = currentUser ==
                                                        null
                                                    ? null
                                                    : ref
                                                        .watch(addressProvider)
                                                        .asData
                                                        ?.value;
                                                final guestLocation =
                                                    currentUser == null
                                                        ? ref.watch(
                                                            guestStorefrontProvider)
                                                        : null;
                                                final hasTrackingBanner = ref
                                                    .watch(
                                                        orderTrackingBannerProvider)
                                                    .isNotEmpty;
                                                return Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: <Widget>[
                                                    const OrderTrackingTopBanner(),
                                                    HomeHeader(
                                                      addressText:
                                                          resolveAddressLabel(
                                                        isLoggedIn:
                                                            currentUser != null,
                                                        addresses: addresses,
                                                        guestAddressLine1:
                                                            guestLocation
                                                                ?.addressLine1,
                                                        guestCity:
                                                            guestLocation?.city,
                                                        guestPincode:
                                                            guestLocation
                                                                ?.pincode,
                                                      ),
                                                      onAddressTap: () {
                                                        if (currentUser ==
                                                            null) {
                                                          showLocationPromptSheet(
                                                            context,
                                                            guestStorefront:
                                                                true,
                                                          );
                                                          return;
                                                        }
                                                        showAddressSheet(
                                                            context);
                                                      },
                                                      topBarTheme: topBarTheme,
                                                      searchZoneColor:
                                                          searchZoneTheme
                                                                  .colorEnabled
                                                              ? searchZoneTheme
                                                                  .backgroundColor
                                                              : Colors
                                                                  .transparent,
                                                      deliveryEtaMinutes:
                                                          deliveryEtaMinutes,
                                                      topPaddingOverride:
                                                          hasTrackingBanner
                                                              ? 0
                                                              : null,
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
                                            color: topBarTheme.colorEnabled
                                                ? topBarTheme.backgroundColor
                                                : Colors.transparent,
                                            child: TickerMode(
                                              enabled: isTopChromeMotionEnabled,
                                              child: child!,
                                            ),
                                          );
                                        },
                                      ),
                                      ValueListenableBuilder<bool>(
                                        valueListenable:
                                            _isTopChromeMotionEnabled,
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
                                                  color: searchZoneTheme
                                                          .colorEnabled
                                                      ? searchZoneTheme
                                                          .backgroundColor
                                                      : Colors.transparent,
                                                  child: TickerMode(
                                                    enabled:
                                                        isTopChromeMotionEnabled,
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: <Widget>[
                                                        const SizedBox.shrink(),
                                                        HomeSearchBar(
                                                          onSearchTap:
                                                              _openSearch,
                                                          animateHints:
                                                              isTopChromeMotionEnabled,
                                                          searchTheme:
                                                              searchZoneTheme,
                                                          outerPadding:
                                                              EdgeInsets
                                                                  .fromLTRB(
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
                                                    color:
                                                        categoryTabsColorEnabled
                                                            ? categoryTabsBgColor
                                                            : Colors
                                                                .transparent,
                                                    child: TickerMode(
                                                      enabled:
                                                          isTopChromeMotionEnabled,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
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
                                                    color: searchZoneTheme
                                                            .colorEnabled
                                                        ? searchZoneTheme
                                                            .backgroundColor
                                                        : Colors.transparent,
                                                    child: Gap(10.h),
                                                  ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Never render old hardcoded campaign widgets as a
                            // loading fallback. A missing remote manifest now
                            // gets an explicit recovery action rather than a
                            // blank area that looks like broken rendering.
                            if (showSkeletonSections)
                              const SliverToBoxAdapter(
                                child: _HomeSectionsSkeleton(),
                              )
                            else if (showSectionsUnavailable)
                              SliverToBoxAdapter(
                                child: _HomeSectionsUnavailable(
                                  // Shows the skeleton again while retrying,
                                  // then either the content or this state.
                                  onRetry: () => ref
                                      .read(storefrontSyncProvider)
                                      .retryActive(),
                                ),
                              )
                            else
                              DynamicHomeSections(
                                key: ValueKey<String>(activeTabKey),
                              ),
                            SliverToBoxAdapter(child: Gap(0)),
                          ],
                        ),
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

/// Used when the header is available but the dashboard-driven section
/// manifest has no content to render. Customers can still search, switch
/// category tabs, set their location, or access notifications while a
/// transient catalogue response is recovered.
class _HomeSectionsUnavailable extends StatelessWidget {
  const _HomeSectionsUnavailable({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 40.h, 20.w, 56.h),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.storefront_outlined,
            size: 42.sp,
            color: AppColors.warmOrangeDark,
          ),
          Gap(14.h),
          Text(
            'Fresh picks are updating',
            textAlign: TextAlign.center,
            style: AppTextStyles.h2.copyWith(fontSize: 19.sp),
          ),
          Gap(8.h),
          Text(
            'We could not load the latest catalogue. Please try again.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Gap(18.h),
          FilledButton.icon(
            onPressed: () => unawaited(onRetry()),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry catalogue'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warmOrangeDark,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
            ),
          ),
        ],
      ),
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
                width: double.infinity,
                height: 160.h,
                radius: 24,
                useOwnShimmer: false),
            Gap(16.h),
            // Section header skeleton
            SkeletonLoader(
                width: 160.w, height: 18.h, radius: 10, useOwnShimmer: false),
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
                width: 140.w, height: 18.h, radius: 10, useOwnShimmer: false),
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

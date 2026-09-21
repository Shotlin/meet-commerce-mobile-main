import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/notifications/notification_router.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';
import 'package:bakaloo_flutter_app/features/location/presentation/providers/guest_storefront_provider.dart';
import 'package:bakaloo_flutter_app/features/location/presentation/widgets/guest_location_gate.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/bill_summary_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_enhancement_providers.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/notifications/presentation/providers/notification_provider.dart';
import 'package:bakaloo_flutter_app/features/notifications/presentation/providers/unread_count_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_live_sync_provider.dart';
import 'package:bakaloo_flutter_app/features/tracking/presentation/providers/order_status_stream_provider.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:bakaloo_flutter_app/routing/route_access.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_route_loading_gate.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    required this.navigationShell,
    required this.branchNavigatorKeys,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final List<GlobalKey<NavigatorState>> branchNavigatorKeys;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  // Drives the footer nav reveal. 1.0 = fully visible, 0.0 = hidden.
  late final AnimationController _navController;
  late final Animation<double> _navAnimation;

  @override
  void initState() {
    super.initState();
    _navController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 200),
      value: 1,
    );
    _navAnimation = CurvedAnimation(
      parent: _navController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    // AppShell is the single always-mounted root shell, so it's the one
    // place that can reliably surface a cart-mutation failure even when
    // the screen that triggered it (a product card's +/- button) has
    // since been navigated away from — see cartMutationFailureNotifier.
    cartMutationFailureNotifier.addListener(_handleCartMutationFailure);
  }

  @override
  void dispose() {
    cartMutationFailureNotifier.removeListener(_handleCartMutationFailure);
    _navController.dispose();
    super.dispose();
  }

  void _handleCartMutationFailure() {
    final failure = cartMutationFailureNotifier.value;
    if (failure == null || !mounted) return;
    showCartSnackBar(context, failure.message);
    // Reset so the same failure doesn't re-fire on the next listener
    // attach (e.g. after a hot navigation remounts AppShell in tests).
    cartMutationFailureNotifier.value = null;
  }

  void _showNav() {
    if (_navController.status != AnimationStatus.completed) {
      _navController.forward();
    }
  }

  void _hideNav() {
    if (_navController.status != AnimationStatus.dismissed) {
      _navController.reverse();
    }
  }

  bool _handleScroll(UserScrollNotification notification) {
    // Ignore horizontal scrollers (carousels, chip rows) — only vertical
    // page scrolling should toggle the footer.
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    // Keep the bar visible when the content isn't tall enough to scroll.
    if (notification.metrics.maxScrollExtent <= 0) {
      _showNav();
      return false;
    }
    switch (notification.direction) {
      case ScrollDirection.reverse:
        _hideNav();
      case ScrollDirection.forward:
        _showNav();
      case ScrollDirection.idle:
        break;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final guestStorefront = ref.watch(guestStorefrontProvider);

    // Do not rely on the asynchronous storefront-access wrapper for guests:
    // it can retain its initial `false` value while the locally saved guest
    // storefront token has already restored. Watching the source state here
    // makes a cold reopen immediately leave the skeleton without a second
    // location prompt or location API call.
    if (authState is! AuthAuthenticated) {
      if (!guestStorefront.isReady) {
        return GuestLocationGate(state: guestStorefront);
      }
    } else {
      final storefrontAccess = ref.watch(storefrontAccessProvider);
      if (storefrontAccess.value != true) {
        return GuestLocationGate(state: guestStorefront);
      }
    }

    final navigationShell = widget.navigationShell;
    final branchNavigatorKeys = widget.branchNavigatorKeys;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final selectedIndex = navigationShell.currentIndex;
    final liveSyncController = ref.read(orderLiveSyncControllerProvider);
    final authGate = ref.read(authGateControllerProvider);
    final routeLoadingController = ref.read(appRouteLoadingProvider.notifier);
    final currentBranchNavigator =
        branchNavigatorKeys[selectedIndex].currentState;
    final branchCanPop = currentBranchNavigator?.canPop() ?? false;

    ref
      ..listen(socketNotificationStreamProvider, (previous, next) {
        next.whenData((event) {
          ref.read(notificationProvider.notifier).addSocketNotification(event);
          ref.invalidate(unreadCountProvider);
          // Admin credit, refund, cashback, topup-approved — all arrive as
          // this same generic push with type PAYMENT/WALLET (see
          // NotificationRouter.getPath's routing for those types to the
          // wallet screen). Nothing else invalidates the keepAlive
          // walletProvider in response to a backend-initiated balance
          // change, so without this the balance only catches up the next
          // time some other screen happens to refetch it.
          const walletNotificationTypes = <String>{'PAYMENT', 'WALLET'};
          if (walletNotificationTypes.contains(event.type.toUpperCase())) {
            ref.invalidate(walletProvider);
          }
          // Order/rider status pushes are already surfaced by the purple
          // OrderTrackingTopBanner on the Home screen (driven by the same
          // underlying order-status change) — showing this generic banner
          // too would put two banners on screen for one event. Every other
          // notification type (promos, wallet, admin broadcasts...) still
          // gets the banner since nothing else displays those.
          const orderStatusTypes = <String>{
            'ORDER_STATUS',
            'ORDER_UPDATE',
            'DELIVERY',
            'RIDER_UPDATE',
          };
          if (orderStatusTypes.contains(event.type.toUpperCase())) {
            return;
          }
          final messenger = ScaffoldMessenger.maybeOf(context);
          if (messenger == null) return;
          messenger
            ..clearMaterialBanners()
            ..showMaterialBanner(
              MaterialBanner(
                backgroundColor: AppColors.bgCard,
                leading: PhosphorIcon(
                  PhosphorIcons.bellRinging,
                  color: AppColors.primaryGreen,
                ),
                content: Text(
                  '${event.title}\n${event.body}',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      messenger.clearMaterialBanners();
                      final path = NotificationRouter.getPath(
                        <String, dynamic>{...event.data, 'type': event.type},
                      );
                      if (path != null && context.mounted) context.go(path);
                    },
                    child: const Text('Open'),
                  ),
                  TextButton(
                    onPressed: messenger.clearMaterialBanners,
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            );
          Future<void>.delayed(const Duration(seconds: 4), () {
            messenger.clearMaterialBanners();
          });
        });
      })
      ..listen(orderStatusStreamProvider, (previous, next) {
        next.whenData((event) {
          liveSyncController.handleStatusEvent(event);
        });
      });

    return PopScope(
      canPop: selectedIndex == 0 && !branchCanPop,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final currentNavigator =
            branchNavigatorKeys[selectedIndex].currentState;
        if (currentNavigator?.canPop() ?? false) {
          await currentNavigator!.maybePop();
          return;
        }
        if (selectedIndex != 0) navigationShell.goBranch(0);
      },
      child: Scaffold(
        extendBody: false,
        body: Stack(
          children: <Widget>[
            NotificationListener<UserScrollNotification>(
              onNotification: _handleScroll,
              child: navigationShell,
            ),
            _CartPillHost(
              selectedIndex: selectedIndex,
              navAnimation: _navAnimation,
              bottomInset: bottomInset,
              onTapCart: () {
                HapticFeedback.lightImpact();
                if (!authGate.isAuthenticated && context.mounted) {
                  authGate.protectRoute(
                    context,
                    route: RouteNames.cart,
                    title: 'Log in to view your cart',
                    message:
                        'Please log in first to review your items and continue to checkout.',
                  );
                  return;
                }
                context.push(RouteNames.cart);
              },
            ),
          ],
        ),
        bottomNavigationBar: SizeTransition(
          sizeFactor: _navAnimation,
          axisAlignment: -1,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFFFBF9FF),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 20,
                  offset: Offset(0, -6),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  12.w,
                  4.h,
                  12.w,
                  bottomInset > 0 ? 2.h : 4.h,
                ),
                child: Row(
                  children: List<Widget>.generate(_tabs.length, (index) {
                    final tab = _tabs[index];
                    return Expanded(
                      child: _NavTabButton(
                        tab: tab,
                        selected: index == selectedIndex,
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          if (index == selectedIndex) return;
                          final nextPath = tab.path;
                          if (RouteAccess.isProtectedTab(nextPath) &&
                              !authGate.isAuthenticated &&
                              context.mounted) {
                            // Remember the intent then go directly to phone screen
                            // (avoids stale context issue after bottom sheet closes)
                            authGate.rememberRouteIntent(nextPath);
                            if (context.mounted) {
                              context.push(RouteNames.phone);
                            }
                            return;
                          }
                          // Reveal the footer whenever the user switches tabs.
                          _showNav();
                          await routeLoadingController.playForFooterNavigation(
                            () => navigationShell.goBranch(index),
                          );
                        },
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The states the Smart Bottom Bar can be in, in priority order (first
/// matching state wins — see [_resolveSmartBarState]). Order tracking used
/// to be a state here too, but that's now shown exclusively by the purple
/// OrderTrackingTopBanner on the Home screen — showing it in both places
/// duplicated the same message.
enum _SmartBarStateKind {
  milestoneProgress,
  unlocked,
  plainCart,
}

class _SmartBarState {
  /// [message] is fully pre-rendered by the caller — either the
  /// free-delivery default ("Add ₹X more to unlock FREE DELIVERY") or an
  /// admin-authored cart-milestone message ("Add ₹200 more to get ₹20
  /// cashback"), whichever tier is closer to being unlocked. [ladder] is
  /// the full merged sequence of checkpoints (free delivery + every
  /// eligible milestone tier) so the bar can render one continuous
  /// segmented progress track instead of resetting to 0% per tier.
  const _SmartBarState.milestone({
    required this.cartCount,
    required this.amountToUnlock,
    required this.progress,
    required this.message,
    this.ladder = const <CartMilestoneLadderStep>[],
  }) : kind = _SmartBarStateKind.milestoneProgress;

  /// [message] is the reward that was actually unlocked — "Free delivery
  /// unlocked" or an admin-authored message like "₹100 cashback unlocked".
  const _SmartBarState.unlocked({
    required this.cartCount,
    required this.message,
    this.ladder = const <CartMilestoneLadderStep>[],
  })  : kind = _SmartBarStateKind.unlocked,
        amountToUnlock = 0,
        progress = 1;

  const _SmartBarState.plainCart({required this.cartCount})
      : kind = _SmartBarStateKind.plainCart,
        message = null,
        amountToUnlock = 0,
        progress = 0,
        ladder = const <CartMilestoneLadderStep>[];

  final _SmartBarStateKind kind;
  final String? message;
  final int cartCount;
  final List<CartMilestoneLadderStep> ladder;
  final double amountToUnlock;
  final double progress;
}

class _CartPillHost extends ConsumerStatefulWidget {
  const _CartPillHost({
    required this.selectedIndex,
    required this.navAnimation,
    required this.bottomInset,
    required this.onTapCart,
  });

  final int selectedIndex;
  final Animation<double> navAnimation;
  final double bottomInset;
  final VoidCallback onTapCart;

  /// The bar should only appear on product-related tabs:
  /// 0 = Home (includes search, product detail sub-routes)
  /// 2 = Categories (includes category product pages)
  /// NOT on Orders (1) or Profile (3) or address/settings sub-pages.
  static bool _isProductTab(int tabIndex) => tabIndex == 0 || tabIndex == 2;

  @override
  ConsumerState<_CartPillHost> createState() => _CartPillHostState();
}

class _CartPillHostState extends ConsumerState<_CartPillHost> {
  bool _cartWasResolving = false;

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);
    final cartCount = ref.watch(cartCountProvider);
    // On a cold start, `cartProvider` briefly sits in `AsyncLoading` before
    // its first `GET /cart` resolves — during that window `cartCount` reads
    // 0 (indistinguishable from "cart is genuinely empty"), which used to
    // force the bar off-screen and then slide back in once the real count
    // arrived, reading as an unexplained "jump" a moment after launch. Only
    // trust a 0 count as "truly empty" once we have actual data (or the
    // fetch failed) — while still loading with no prior value, hold off on
    // deciding at all rather than flashing hidden→shown.
    final cartStillResolving = cartAsync.isLoading && !cartAsync.hasValue;
    // Read *last* frame's resolving state before overwriting it — the
    // frame where resolving just finished (this frame: false, previous
    // frame: true) is the one that needs the zero-duration pop-in; every
    // frame after that goes back to the normal animated slide.
    final wasResolvingLastFrame = _cartWasResolving;
    _cartWasResolving = cartStillResolving;
    final billSummaryAsync =
        cartCount > 0 ? ref.watch(billSummaryProvider) : null;

    final billSummary = billSummaryAsync?.value;

    _SmartBarState? state;
    if (cartCount > 0) {
      final free = billSummary?.freeDelivery;
      final nextTier = billSummary?.cartMilestone.next;
      final unlockedTier = billSummary?.cartMilestone.unlocked;
      final rewardLadder = billSummary?.cartMilestone.ladder ??
          const <CartMilestoneLadderStep>[];

      final freeDeliveryAmount = (free != null &&
              free.enabled &&
              !free.unlocked &&
              free.amountToUnlock > 0)
          ? free.amountToUnlock
          : null;

      // Show whichever goal is closer — the more motivating "almost there"
      // message — rather than always defaulting to free delivery.
      final showMilestone = nextTier != null &&
          (freeDeliveryAmount == null ||
              nextTier.amountToUnlock <= freeDeliveryAmount);

      if (showMilestone) {
        final threshold = nextTier.minCartAmount;
        final progress = threshold > 0
            ? (1 - (nextTier.amountToUnlock / threshold)).clamp(0.0, 1.0)
            : 0.0;
        state = _SmartBarState.milestone(
          cartCount: cartCount,
          amountToUnlock: nextTier.amountToUnlock,
          progress: progress,
          message: nextTier.message.isNotEmpty
              ? nextTier.message
              : 'Add ₹${nextTier.amountToUnlock.toStringAsFixed(0)} more to unlock ${nextTier.name}',
          ladder: rewardLadder,
        );
      } else if (freeDeliveryAmount != null) {
        final threshold = free?.threshold ?? 0;
        final progress = threshold > 0
            ? (1 - (freeDeliveryAmount / threshold)).clamp(0.0, 1.0)
            : 0.0;
        state = _SmartBarState.milestone(
          cartCount: cartCount,
          amountToUnlock: freeDeliveryAmount,
          progress: progress,
          message:
              'Add ₹${freeDeliveryAmount.toStringAsFixed(0)} more to unlock FREE DELIVERY',
          ladder: rewardLadder,
        );
      } else if (unlockedTier != null) {
        state = _SmartBarState.unlocked(
          cartCount: cartCount,
          message: unlockedTier.message.isNotEmpty
              ? unlockedTier.message
              : '${unlockedTier.name} unlocked',
          ladder: rewardLadder,
        );
      } else if (free != null && free.unlocked) {
        state = _SmartBarState.unlocked(
          cartCount: cartCount,
          message: 'Free delivery unlocked',
          ladder: rewardLadder,
        );
      } else {
        state = _SmartBarState.plainCart(cartCount: cartCount);
      }
    }

    // Full-width bar with a comfortable side margin, sitting just above the
    // bottom nav. When the footer nav is hidden the body grows to the screen
    // edge, so we keep a comfortable gap above the safe area instead of
    // dropping under the home indicator — the bar glides down with the nav
    // without ever clipping.
    final hiddenGap = widget.bottomInset > 0 ? widget.bottomInset : 10.h;
    final horizontalMargin = 12.w;

    return ValueListenableBuilder<bool>(
      valueListenable: productOptionSheetVisible,
      builder: (context, isProductSheetOpen, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: addressSheetVisible,
          builder: (context, isAddressSheetOpen, _) {
            final showBar = state != null &&
                !isProductSheetOpen &&
                !isAddressSheetOpen &&
                _CartPillHost._isProductTab(widget.selectedIndex);
            // The cold-start resolving window (see `cartStillResolving`
            // above) is the one case where the bar transitions from
            // hidden to shown for a reason the user didn't cause — the
            // cart fetch simply hadn't finished on the very first frame.
            // Popping it in instantly there (vs. the normal slide-up
            // used for genuine cart-becomes-non-empty transitions) avoids
            // it reading as an unexplained jump right after launch.
            final poppingInFromColdStart =
                cartStillResolving || wasResolvingLastFrame;
            final slideDuration = poppingInFromColdStart
                ? Duration.zero
                : const Duration(milliseconds: 280);
            final fadeDuration = poppingInFromColdStart
                ? Duration.zero
                : const Duration(milliseconds: 220);
            return AnimatedBuilder(
              animation: widget.navAnimation,
              builder: (context, child) {
                final bottomOffset =
                    8.h + hiddenGap * (1 - widget.navAnimation.value);
                return Positioned(
                  bottom: bottomOffset,
                  left: horizontalMargin,
                  right: horizontalMargin,
                  child: child!,
                );
              },
              child: IgnorePointer(
                ignoring: !showBar,
                child: RepaintBoundary(
                  child: AnimatedSlide(
                    offset: showBar ? Offset.zero : const Offset(0, 1.5),
                    duration: slideDuration,
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: showBar ? 1.0 : 0.0,
                      duration: fadeDuration,
                      curve: Curves.easeOut,
                      child: state == null
                          ? const SizedBox.shrink()
                          : _SmartBottomBar(
                              state: state,
                              onTap: widget.onTapCart,
                            ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SmartBottomBar extends StatelessWidget {
  const _SmartBottomBar({
    required this.state,
    required this.onTap,
  });

  final _SmartBarState state;
  final VoidCallback onTap;

  static const Color _barColor = Color(0xFFD02428);
  static const Color _successColor = Color(0xFF12B76A);

  @override
  Widget build(BuildContext context) {
    final bool isUnlocked = state.kind == _SmartBarStateKind.unlocked;
    final Color barColor = isUnlocked ? _successColor : _barColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: barColor,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: barColor.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 12.w, 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(child: _buildMessage(context)),
                  Gap(10.w),
                  _buildCartSummary(context),
                  Gap(6.w),
                  PhosphorIcon(
                    PhosphorIcons.caretRightBold,
                    size: 18.sp,
                    color: Colors.white,
                  ),
                ],
              ),
              if (state.kind != _SmartBarStateKind.plainCart) ...<Widget>[
                Gap(10.h),
                state.ladder.isNotEmpty
                    ? _RewardLadderTrack(steps: state.ladder)
                    : _ProgressLine(progress: state.progress),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(BuildContext context) {
    switch (state.kind) {
      case _SmartBarStateKind.milestoneProgress:
        return Text(
          state.message ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13.sp,
            height: 1.25,
          ),
        );
      case _SmartBarStateKind.unlocked:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PhosphorIcon(
              PhosphorIcons.sealCheckFill,
              size: 18.sp,
              color: Colors.white,
            ),
            Gap(8.w),
            Flexible(
              child: Text(
                state.message ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],
        );
      case _SmartBarStateKind.plainCart:
        return Text(
          'View cart',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15.sp,
          ),
        );
    }
  }

  Widget _buildCartSummary(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              'CART',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11.sp,
                letterSpacing: 0.4,
                height: 1.1,
              ),
            ),
            Text(
              '${state.cartCount} ITEM${state.cartCount == 1 ? '' : 'S'}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
                fontSize: 9.5.sp,
                letterSpacing: 0.2,
                height: 1.1,
              ),
            ),
          ],
        ),
        Gap(8.w),
        Container(
          width: 32.w,
          height: 32.w,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(8.r),
          ),
          alignment: Alignment.center,
          child: PhosphorIcon(
            PhosphorIcons.basketFill,
            size: 16.sp,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Segmented progress track — one segment per checkpoint in the merged
/// reward ladder (free delivery + every eligible cart-milestone tier),
/// each with its own small gap marking the tier boundary. An already-passed
/// segment stays fully filled; the current segment fills proportionally
/// within its own span; segments further ahead sit visibly empty so the
/// customer can always see there's more to unlock, instead of the bar
/// resetting to 0% (and looking "finished") every time a tier is crossed.
/// Once every segment is achieved the whole track reads as one continuous
/// filled line, save for the thin boundary gaps.
class _RewardLadderTrack extends StatelessWidget {
  const _RewardLadderTrack({required this.steps});

  final List<CartMilestoneLadderStep> steps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < steps.length; i++) ...<Widget>[
          if (i > 0) Gap(4.w),
          Expanded(child: _LadderSegment(progress: steps[i].segmentProgress)),
        ],
      ],
    );
  }
}

class _LadderSegment extends StatelessWidget {
  const _LadderSegment({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4.r),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return Stack(
            children: <Widget>[
              Container(
                  height: 5.h, color: Colors.white.withValues(alpha: 0.25)),
              FractionallySizedBox(
                widthFactor: value,
                child: Container(
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4.r),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                          color: Colors.white.withValues(alpha: 0.6),
                          blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Thin rounded progress track shown under the milestone message — a
/// lightweight, bottom-bar-specific indicator (the fuller bill-summary
/// progress widget on the cart screen has different sizing/styling needs).
/// Fallback for when the backend hasn't returned a reward ladder (older
/// payload shape, or truly nothing configured) — a single bar is still
/// better than nothing.
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4.r),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return Stack(
            children: <Widget>[
              Container(
                height: 5.h,
                color: Colors.white.withValues(alpha: 0.25),
              ),
              FractionallySizedBox(
                widthFactor: value,
                child: Container(
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4.r),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavTabButton extends StatelessWidget {
  const _NavTabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final AppShellTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Matches the red baked into the mc-*-filled-icon.png assets — kept in
    // sync with the label color below so text and icon read as one color,
    // not the old Bakaloo purple next to a red icon.
    const Color activeColor = Color(0xFFD02428);
    const Color inactiveColor = Color(0xFF1A1A1A);
    final String iconAsset = selected ? tab.activeIcon : tab.inactiveIcon;
    final Color labelColor = selected ? activeColor : inactiveColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 6.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 56.w,
                height: 38.h,
                child: Center(
                  child: AnimatedScale(
                    scale: selected ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        selected ? activeColor : inactiveColor,
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(
                        iconAsset,
                        width: 36.w,
                        height: 36.h,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ),
              ),
              Gap(3.h),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: AppTextStyles.labelSmall.copyWith(
                  color: labelColor,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12.sp,
                ),
                child: Text(tab.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppShellTab {
  AppShellTab({
    required this.label,
    required this.path,
    required this.inactiveIcon,
    required this.activeIcon,
  });

  final String label;
  final String path;
  final String inactiveIcon;
  final String activeIcon;
}

const String _footerIconBase = 'assets/icon/footer_icon';

final List<AppShellTab> _tabs = <AppShellTab>[
  AppShellTab(
    label: 'Home',
    path: RouteNames.home,
    inactiveIcon: '$_footerIconBase/mc-home-outline-icon.png',
    activeIcon: '$_footerIconBase/mc-home-filled-icon.png',
  ),
  AppShellTab(
    label: 'Orders',
    path: RouteNames.orders,
    inactiveIcon: '$_footerIconBase/mc-orders-outline-icon.png',
    activeIcon: '$_footerIconBase/mc-orders-filled-icon.png',
  ),
  AppShellTab(
    label: 'Categories',
    path: RouteNames.categories,
    inactiveIcon: '$_footerIconBase/mc-categories-outline-icon.png',
    activeIcon: '$_footerIconBase/mc-categories-filled-icon.png',
  ),
  AppShellTab(
    label: 'Profile',
    path: RouteNames.profile,
    inactiveIcon: '$_footerIconBase/mc-profile-outline-icon.png',
    activeIcon: '$_footerIconBase/mc-profile-filled-icon.png',
  ),
];

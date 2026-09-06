import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/features/notifications/presentation/providers/order_notification_flags_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_timeline_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/active_order_provider.dart';

const Color kOrderBannerBackground = Color(0xFFFFFFFF);

/// The order-notification-settings timeline-type key each status maps to,
/// for looking it up in [orderNotificationFlagsProvider]'s flag map — kept
/// in sync with bakaloo-backend's order-notification-settings.js registry.
String? _notificationEventKeyFor(OrderStatus status) {
  switch (status) {
    case OrderStatus.PENDING:
    case OrderStatus.CONFIRMED:
      return 'CONFIRMED';
    case OrderStatus.PREPARING:
      return 'PREPARING';
    case OrderStatus.PACKED:
      return 'PACKED';
    case OrderStatus.OUT_FOR_DELIVERY:
      return 'PICKED_UP';
    case OrderStatus.DELIVERED:
    case OrderStatus.CANCELLED:
    case OrderStatus.REFUNDED:
      return null;
  }
}

/// Matches the wording already used elsewhere for order-status copy, so
/// nothing contradicts the Orders screen. Stays quiet (returns '') for a
/// status whose matching push/in-app notification is switched off in
/// Settings → Order Notifications — [notificationFlags] missing a key (still
/// loading, fetch failed) defaults to enabled, never to suppressed.
String _bannerMessageFor(OrderStatus status, Map<String, bool> notificationFlags) {
  final eventKey = _notificationEventKeyFor(status);
  if (eventKey != null && notificationFlags[eventKey] == false) {
    return '';
  }

  switch (status) {
    case OrderStatus.PENDING:
    case OrderStatus.CONFIRMED:
      return 'Your order is confirmed';
    case OrderStatus.PREPARING:
      return 'Your order is being packed';
    case OrderStatus.PACKED:
      return 'Your order is packed and ready';
    case OrderStatus.OUT_FOR_DELIVERY:
      return 'Your order is on the way 🚚';
    case OrderStatus.DELIVERED:
    case OrderStatus.CANCELLED:
    case OrderStatus.REFUNDED:
      return '';
  }
}

/// The current order-status text and the order/status pair it came from, or
/// both empty when there's nothing to show. Purely derived from live data —
/// carries no memory of what's already been shown, so it's safe to watch
/// from anywhere without affecting how long the banner stays up.
typedef _RawOrderStatus = ({String message, String key});

final _rawOrderStatusProvider = Provider.autoDispose<_RawOrderStatus>((ref) {
  final activeOrderAsync = ref.watch(activeOrderProvider);
  final notificationFlags =
      ref.watch(orderNotificationFlagsProvider).asData?.value ?? const <String, bool>{};

  // `.value` keeps the last-resolved order while a refetch is in flight
  // (only null before the very first load ever completes), so a socket
  // push invalidating activeOrderProvider doesn't blank this out mid-flight
  // — it just recomputes to the same result until the refetch actually
  // changes something.
  final activeOrder = activeOrderAsync.value;
  if (activeOrder == null || !activeOrder.status.isActive) {
    return (message: '', key: '');
  }

  final message = _bannerMessageFor(activeOrder.status, notificationFlags);
  if (message.isEmpty) {
    return (message: '', key: '');
  }

  return (message: message, key: '${activeOrder.id}::${activeOrder.status.name}');
});

/// Owns "what order-status banner is visible right now", if any — a single
/// source of truth so the banner itself and [OrderTrackingTopBanner]'s
/// home-screen layout neighbor (which needs to know whether to give it
/// room) never disagree.
///
/// Deliberately dumb: nothing in here derives its own value from order
/// data — [OrderTrackingTopBanner] does that via [_rawOrderStatusProvider]
/// and calls [sync] whenever it changes. That split is what makes the
/// 7-second auto-hide reliable: the only two things that can ever change
/// `state` are a genuinely new status arriving through [sync], or this
/// class's own timer — an unrelated rebuild anywhere else in the app has no
/// path to touch it, so it can never restart or resurrect the countdown.
class OrderTrackingBannerController extends Notifier<String> {
  static const _visibleDuration = Duration(seconds: 7);

  Timer? _hideTimer;
  String? _visibleKey;

  @override
  String build() {
    ref.onDispose(() => _hideTimer?.cancel());
    return '';
  }

  /// Call with the latest [_RawOrderStatus] on every change. A repeat call
  /// with the same [key] as what's already showing is a no-op — it does
  /// NOT restart the countdown — so this is always safe to call on every
  /// rebuild without worrying about resetting an already-running timer.
  void sync(String message, String key) {
    if (message.isEmpty) {
      _visibleKey = null;
      _hideTimer?.cancel();
      state = '';
      return;
    }
    if (key == _visibleKey) return;

    _visibleKey = key;
    _hideTimer?.cancel();
    state = message;
    _hideTimer = Timer(_visibleDuration, () {
      // Only clear if this is still the status that started the timer — a
      // newer one may have already taken over and started its own.
      if (_visibleKey == key) {
        _visibleKey = null;
        state = '';
      }
    });
  }
}

final orderTrackingBannerProvider =
    NotifierProvider<OrderTrackingBannerController, String>(
  OrderTrackingBannerController.new,
);

/// A structural — not floating — strip shown at the very top of the
/// Home screen, directly above `HomeHeader`. It occupies real layout space
/// (pushing the header down) instead of overlaying it, and collapses back
/// to zero height a few seconds after each new status update — the header
/// slides back up to normal once it's gone.
class OrderTrackingTopBanner extends ConsumerStatefulWidget {
  const OrderTrackingTopBanner({super.key});

  @override
  ConsumerState<OrderTrackingTopBanner> createState() =>
      _OrderTrackingTopBannerState();
}

class _OrderTrackingTopBannerState
    extends ConsumerState<OrderTrackingTopBanner> {
  @override
  void initState() {
    super.initState();
    // listenManual (not the build-time `listen`) so `fireImmediately` is
    // available — WidgetRef.listen in Riverpod 3 dropped that parameter,
    // but this is exactly the "outside build" lifecycle spot it's meant
    // for. Covers both the very first read (e.g. opening the app straight
    // into an already-active order) and every change after that, feeding
    // them all through the same `sync` call so there's only one place that
    // ever decides whether a status is genuinely new.
    ref.listenManual(
      _rawOrderStatusProvider,
      (previous, next) {
        // Deferred: `fireImmediately` invokes this synchronously from
        // initState, and mutating a provider mid-build throws "Tried to
        // modify a provider while the widget tree was building." A
        // microtask runs right after the current build finishes, which is
        // early enough that the banner still appears with no visible delay.
        Future.microtask(() {
          if (!mounted) return;
          ref.read(orderTrackingBannerProvider.notifier).sync(next.message, next.key);
        });
      },
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = ref.watch(orderTrackingBannerProvider);
    final activeOrderId = ref.watch(activeOrderProvider).value?.id;

    return AnimatedSize(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: message.isEmpty || activeOrderId == null
          ? const SizedBox(width: double.infinity)
          : _BannerBody(
              key: ValueKey(message),
              message: message,
              onTap: () => context.push('/orders/$activeOrderId'),
            ),
    );
  }
}

class _BannerBody extends StatelessWidget {
  const _BannerBody({required this.message, required this.onTap, super.key});

  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipPath(
        clipper: const _ScallopedWaveClipper(),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20.w, topInset + 12.h, 20.w, 20.h),
          color: kOrderBannerBackground,
          alignment: Alignment.center,
          child: Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 15.5.sp,
              color: Colors.black,
              height: 1.25,
            ),
          ),
        ),
      ),
    );
  }
}

/// Repeating scalloped bottom edge — several soft bumps across the width,
/// matching the reference design's wavy bottom border.
class _ScallopedWaveClipper extends CustomClipper<Path> {
  const _ScallopedWaveClipper({this.waveCount = 7, this.waveHeight = 8});

  final int waveCount;
  final double waveHeight;

  @override
  Path getClip(Size size) {
    final double base = size.height - waveHeight;
    final double waveWidth = size.width / waveCount;
    final path = Path()..lineTo(0, base);

    for (int i = 0; i < waveCount; i++) {
      final double startX = i * waveWidth;
      final double midX = startX + waveWidth / 2;
      final double endX = startX + waveWidth;
      path.quadraticBezierTo(midX, base + waveHeight, endX, base);
    }

    return path
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

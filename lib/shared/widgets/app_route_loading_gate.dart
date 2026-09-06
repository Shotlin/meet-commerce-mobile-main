import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const Duration kAppRouteLoadingFadeDuration = Duration(milliseconds: 120);

enum AppRouteLoadingPhase {
  hidden,
  fadingIn,
  covered,
  fadingOut,
}

class AppRouteLoadingState {
  const AppRouteLoadingState({
    this.phase = AppRouteLoadingPhase.hidden,
  });

  final AppRouteLoadingPhase phase;

  bool get isVisible => phase != AppRouteLoadingPhase.hidden;

  AppRouteLoadingState copyWith({
    AppRouteLoadingPhase? phase,
  }) {
    return AppRouteLoadingState(
      phase: phase ?? this.phase,
    );
  }
}

class AppRouteLoadingNotifier extends Notifier<AppRouteLoadingState> {
  static const Duration _settleDuration = Duration(milliseconds: 150);

  bool _isTransitioning = false;

  @override
  AppRouteLoadingState build() {
    return const AppRouteLoadingState();
  }

  Future<void> playForFooterNavigation(
    FutureOr<void> Function() onNavigate,
  ) async {
    if (_isTransitioning) {
      return;
    }

    _isTransitioning = true;

    try {
      state = state.copyWith(phase: AppRouteLoadingPhase.fadingIn);
      await Future<void>.delayed(kAppRouteLoadingFadeDuration);

      state = state.copyWith(phase: AppRouteLoadingPhase.covered);
      await onNavigate();

      await SchedulerBinding.instance.endOfFrame;
      await Future<void>.delayed(_settleDuration);

      state = state.copyWith(phase: AppRouteLoadingPhase.fadingOut);
      await Future<void>.delayed(kAppRouteLoadingFadeDuration);
    } finally {
      state = state.copyWith(phase: AppRouteLoadingPhase.hidden);
      _isTransitioning = false;
    }
  }
}

final appRouteLoadingProvider =
    NotifierProvider<AppRouteLoadingNotifier, AppRouteLoadingState>(
  AppRouteLoadingNotifier.new,
);

class AppRouteLoadingGate extends ConsumerWidget {
  const AppRouteLoadingGate({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadingState = ref.watch(appRouteLoadingProvider);
    final phase = loadingState.phase;
    final showOverlay = loadingState.isVisible;
    final targetOpacity = switch (phase) {
      AppRouteLoadingPhase.fadingOut => 0.0,
      AppRouteLoadingPhase.hidden => 0.0,
      AppRouteLoadingPhase.fadingIn => 1.0,
      AppRouteLoadingPhase.covered => 1.0,
    };

    return Stack(
      children: <Widget>[
        child,
        if (showOverlay)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: targetOpacity,
                duration: kAppRouteLoadingFadeDuration,
                curve: Curves.easeInOutCubic,
                // Plain background — no animation widget.
                child: const ColoredBox(
                  color: Color.fromARGB(255, 241, 244, 249),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

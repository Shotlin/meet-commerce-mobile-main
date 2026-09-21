import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/core/notifications/fcm_service.dart';
import 'package:bakaloo_flutter_app/core/theme/app_theme.dart';
import 'package:bakaloo_flutter_app/routing/app_router.dart';
import 'package:bakaloo_flutter_app/shared/providers/theme_provider.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_availability_gate.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_route_loading_gate.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_version_gate.dart';

// The phone this design was tuned for. Android phones and iPhones (incl.
// iPhone 17 Pro) all sit close to this width, so ScreenUtil's scale factor
// stays near 1x and every `.w`/`.h`/`.sp` value renders as designed.
const Size _phoneDesignSize = Size(390, 844);

// iPads are far wider/taller than the phone reference (e.g. ~1024x1366 on a
// 13" iPad vs 390x844 here), so scaling every dimension by the raw ratio
// blows past what fixed-height widgets (e.g. CategoryTabsRow) budget for,
// causing RenderFlex overflows tablet-only. Capping the scale keeps tablet
// UI proportionally bigger than phone without letting it run away.
const double _maxTabletScale = 1.3;

Size _resolveDesignSize(BuildContext context) {
  final Size screenSize = MediaQuery.sizeOf(context);
  if (screenSize.shortestSide < 600) {
    return _phoneDesignSize;
  }
  return Size(
    screenSize.width / _maxTabletScale,
    screenSize.height / _maxTabletScale,
  );
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(initializeFcmProvider);
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return ScreenUtilInit(
      designSize: _resolveDesignSize(context),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp.router(
          theme: AppTheme.lightTheme,
          themeMode: themeMode,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          builder: (BuildContext context, Widget? child) {
            final textScaleFactor = MediaQuery.of(context)
                .textScaler
                .scale(1)
                .clamp(0.8, 1.2)
                .toDouble();
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScaleFactor),
              ),
              child: AppVersionGate(
                child: AppAvailabilityGate(
                  child: AppRouteLoadingGate(
                    child: child ?? const SizedBox.shrink(),
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

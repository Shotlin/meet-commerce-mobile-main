import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/notifications/fcm_service.dart';

void initializePlatformNotifications(WidgetRef ref) {
  ref.watch(initializeFcmProvider);
}

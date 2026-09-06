import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/app.dart';
import 'package:bakaloo_flutter_app/core/constants/app_constants.dart';
import 'package:bakaloo_flutter_app/core/diagnostics/startup_diagnostics.dart';
import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/core/storage/remote_layout_cache_manager.dart';
import 'package:bakaloo_flutter_app/firebase_options.dart';

/// On iOS, the native Firebase SDK auto-configures the default app from
/// GoogleService-Info.plist before Dart ever runs — so calling
/// initializeApp() unconditionally always throws `core/duplicate-app` here.
/// A `Firebase.apps.isEmpty` pre-check is NOT reliable either: the Dart-side
/// cache can still read empty at this point even though the native side has
/// already configured the app (the two aren't synchronously in sync this
/// early in startup). The only reliable fix is to attempt initialization
/// and treat `duplicate-app` specifically as success — everything else
/// still surfaces as a real failure.
Future<void> _ensureFirebaseInitialized() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await _ensureFirebaseInitialized();
  } catch (e) {
    debugPrint('Firebase background init failed (dummy keys?): $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  try {
    // Previously this call threw `core/duplicate-app` on every single iOS
    // launch (see _ensureFirebaseInitialized doc comment), which silently
    // skipped everything below it in this try block — onBackgroundMessage
    // registration and the Crashlytics global error hooks — on every real
    // iOS run. Android has no equivalent native auto-init, which is why
    // this only ever broke iOS.
    await _ensureFirebaseInitialized();
    debugPrint('Firebase initialized');

    if (!kDebugMode) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }

    FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler,
    );
  } catch (e) {
    debugPrint('Firebase init failed (dummy keys?): $e');
  }

  await HiveService.init();
  debugPrint('Hive initialized');

  // PHASE 2 FIX: App-wide cache reconciliation. Wipes ALL non-auth caches
  // when the app cache schema version OR the API base URL changes — so an
  // updated build / different backend can never render stale login/cart/
  // theme/wallet UI. Auth tokens are preserved.
  await AppCacheManager.ensureFreshOnStartup();
  debugPrint('App cache schema verified');

  // Wipe stale remote layout caches whenever the schema version changes.
  // This prevents old summer/campaign UI from bleeding in after a deployment.
  await RemoteLayoutCacheManager.ensureCurrentVersion();
  debugPrint('Remote layout cache version verified');

  // PHASE 1 FIX: Print startup self-diagnostics (debug/profile only — no-op
  // in release). Confirms build mode, API URL, network type, auth state and
  // cache versions so a "stale old UI" report can be triaged in seconds.
  await StartupDiagnostics.log();

  PaintingBinding.instance.imageCache.maximumSizeBytes =
      AppConstants.imageCacheSizeMB * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize =
      AppConstants.imageCacheMaxCount;

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}

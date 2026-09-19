# Bakaloo Flutter Web/PWA readiness audit

**Audit date:** 2026-09-08
**Repository baseline:** `main` at `aae571d7130c06c7e379eab66f8bd8bd4c7a0e0b` (clean after checkout)
**Evidence standard:** `VERIFIED` is backed by the checked-out code or a safe request made during this audit. `UNVERIFIED` has not been inferred as fact.

## Executive finding

At the audit baseline the repository was a Flutter mobile application with no `web/` target, unavailable local toolchain, unconditional native startup, a bundled `.env`, Firebase Web exceptions, a mobile-only Razorpay SDK, and an API origin that rejected browser CORS preflights. The incremental implementation below now has a compiling Web target, conditional platform boundaries, clean path URLs, PWA assets and a verified release build. Browser commerce remains gated by the external CORS/Firebase/payment/host prerequisites recorded here.

The correct path is incremental: add a Web target and a small set of platform boundaries while reusing the existing Riverpod, GoRouter, Dio, repository, use-case, and feature layers. No API or payment contract should be invented.

## A. Existing architecture

| Area | Finding | Evidence |
|---|---|---|
| Entrypoint | `main()` initializes dotenv, Firebase, Hive/cache managers and starts a root `ProviderScope`. | `lib/main.dart:main` |
| Application shell | `App` uses `MaterialApp.router`, `ScreenUtilInit`, themed Riverpod state, and app availability/version/loading gates. | `lib/app.dart:App` |
| State management | Riverpod + Riverpod generator annotations. | `pubspec.yaml`, `lib/core/di/providers.dart`, feature `presentation/providers/` |
| Routing | GoRouter with redirect guard and `StatefulShellRoute.indexedStack`; route state is currently held in `state.extra` for some screens. | `lib/routing/app_router.dart`, `route_guards.dart`, `route_access.dart` |
| Feature boundaries | Most commerce features use `data/datasources`, `data/repositories`, `domain/entities`, `domain/repositories`, `domain/usecases`, and `presentation`. | `lib/features/*` |
| API abstraction | Retrofit `ApiClient` over a shared Dio instance; data sources parse endpoint payloads and repositories map failures. | `lib/core/network/api_client.dart`, `dio_client.dart`, feature data sources |
| Storage | Secure tokens use `flutter_secure_storage`; Hive keeps cache, settings, profile and order data. Sensitive Hive boxes are encrypted on native. | `lib/core/storage/secure_storage_service.dart`, `hive_service.dart` |
| Error handling | Dio interceptors include availability, connectivity, refresh, logging and error mapping. | `lib/core/network/dio_client.dart`, `refresh_interceptor.dart`, `api_interceptor.dart` |
| Analytics/logging | Firebase Crashlytics hooks run outside debug builds; Firebase Analytics is declared. | `lib/main.dart`, `pubspec.yaml` |

The architecture table records the pre-migration state. Current platform boundaries and verification evidence are summarized in the post-audit section below.

## B. Verified backend contract in code

`ApiConstants` reads public `BASE_URL` and `SOCKET_URL` compile-time defines through `AppConfig`; therefore the checked-out source does **not** verify a concrete deployed base URL. The expected `https://api.fc.opslin.com/api/v1` is externally supplied and was used only for the local release-build command.

Verified client-side declarations include OTP (`/auth/send-otp`, `/auth/verify-otp`, `/auth/refresh-token`), catalogue/products/categories, cart, address, checkout/order, Razorpay payment creation/verification/status, wallet, wishlist, reviews, notifications, remote theme/layout, allocation and upload endpoints. See `lib/core/constants/api_constants.dart` and `lib/core/network/api_client.dart`.

Authentication is `VERIFIED` as an Authorization-header flow: `AuthRepositoryImpl` persists access and refresh tokens, and `ApiInterceptor` sends `Authorization: Bearer <access token>`. `RefreshInterceptor` serializes refresh attempts and forces logout after confirmed refresh rejection. See `lib/features/auth/data/repositories/auth_repository_impl.dart`, `lib/core/network/api_interceptor.dart`, and `lib/core/network/refresh_interceptor.dart`.

Payment verification is `VERIFIED` as a backend operation: `PaymentRemoteDataSource.verifyPayment()` posts to `/payments/verify`; the client also polls `/payments/status/:razorpayOrderId` after ambiguous SDK outcomes. The exact server-side verification algorithm is `UNVERIFIED` because the backend repository is unavailable.

## C. Routing and deep-link readiness

Meaningful URLs already exist for auth, search, product ID/slug, cart/checkout, shell tabs, orders/order tracking, categories, profile, wallet, wishlist, addresses, notifications and reviews. Product links support both `/product/:productId` and `/products/:slug`; protected paths are `/cart`, `/orders`, and `/profile`.

`PARTIALLY VERIFIED`: GoRouter now uses Flutter's path URL strategy and the local release build booted at `/home` without a hash fragment. Direct refresh still requires the eventual host to rewrite unknown application paths to `index.html`. Routes relying on `state.extra` (for example location/address editing flows) need URL-safe restoration or a controlled refresh fallback.

## D. Web compatibility matrix

The pinned dependencies were provisioned for the verification loop. Classifications below combine source usage with the checked-out package metadata; items marked `UNVERIFIED` still require a product-specific browser check.

| Dependency / area | Classification | Required adaptation |
|---|---|---|
| Flutter Riverpod, GoRouter, Dio, Retrofit | Web supported unchanged | Reuse shared logic; add browser route tests. |
| `socket_io_client` | UNVERIFIED | Validate its pinned version's browser transport/auth behavior against the actual socket URL. |
| `http_certificate_pinning` | Feature gate required | Certificate pinning cannot operate in browser JavaScript; remove only from Web Dio setup. |
| `flutter_secure_storage` | Web supported with configuration | Use an explicit Web session-storage policy; do not describe browser storage as hardware-secure. |
| Hive + `path_provider` | Web implementation required | `HiveService.init()` calls `getApplicationDocumentsDirectory()`; create a Web-safe initialization path and reassess encrypted-box behavior. |
| `razorpay_flutter` | Replacement package / adapter required | `RazorpayService` directly imports the mobile SDK. Implement an injected platform checkout adapter using an officially supported Web Checkout integration; preserve `/payments/verify`. |
| Firebase Core/Messaging | Web supported with configuration | Legitimate Firebase Web options, VAPID key strategy and messaging service worker are required. |
| Crashlytics | Remove from Web initialization | Current Flutter setup is mobile-specific; keep a Web error-reporting boundary without claiming crash reporting works until configured. |
| Firebase Analytics | Web supported with configuration | Needs genuine Firebase Web configuration. |
| `flutter_local_notifications` | Graceful fallback required | Browser notifications are Web Push/browser notifications, not native local notifications. |
| `maplibre_gl` | Web build verified | Native hybrid-composition setup is isolated; browser map rendering still needs a location-enabled flow check. |
| `geolocator` | Web supported with configuration | Use browser permission/denial UX and a manual address fallback. |
| `location` | Feature gate required | It is used for Android SettingsClient behavior in `location_service_resolver.dart`; no browser equivalent. |
| `geocoding` | Native-only isolated | Browser reverse geocoding uses the existing backend Ola proxy; native geocoding is selected only on mobile. |
| `flutter_jailbreak_detection`, screenshot prevention | Feature gate required | No meaningful browser equivalent. |
| `open_file` / `dart:io` invoice flow | Web implementation required | Use download/new-tab rather than native files. |
| `local_auth` | Graceful fallback required | Do not simulate biometrics; WebAuthn requires an actual product/backend design. |
| `in_app_review` | Feature gate required | Do not invoke native store review on Web. |
| `speech_to_text` | UNVERIFIED | Browser support and permission UX must be checked against the locked version. |
| `wakelock_plus`, `share_plus`, `package_info_plus`, YouTube player | UNVERIFIED | Validate pinned Web support; add safe fallback where unavailable. |

The baseline direct Web compilation blockers were removed with conditional platform boundaries. Native-only imports now stay behind adapters; remaining browser limitations are honest feature gates (Firebase, Razorpay, native notifications/security, and host/API configuration).

## E. Firebase, notifications, realtime and security

* **Firebase — BLOCKED — external configuration required.** `DefaultFirebaseOptions.currentPlatform` throws on `kIsWeb`, and only intentional Android/iOS placeholder options exist (`lib/firebase_options.dart`). No Firebase Web app/VAPID/service worker configuration is present.
* **Notifications — PARTIALLY VERIFIED.** `FCMService` requests permission, registers tokens with `/notifications/tokens`, handles foreground/cold-start navigation, and `LocalNotificationService` is Android/iOS-specific. A Web adapter must provide only real browser-notification behavior.
* **Socket.IO — PARTIALLY VERIFIED.** `SocketService` now reads the public `ApiConstants.socketUrl` define and reconnects after token refresh. Namespaces/transports/origin policy still require a safe browser check against the deployed socket origin. See `lib/core/socket/socket_service.dart` and `socket_events.dart`.
* **Security finding — RESOLVED IN SOURCE.** `.env` is no longer a Flutter asset; Web-safe endpoint values come from compile-time public defines. SSL pinning remains native-only and no secrets are supplied by the Web build command.
* **Security finding — HIGH.** Browser-side CORS is not currently viable for the supplied expected API origin. Safe request evidence: on 2026-09-08 an Origin-bearing `GET https://api.fc.opslin.com/api/v1/products?limit=1` returned `200` without `Access-Control-Allow-Origin`; the matching OPTIONS preflight returned `404` without browser allow headers. This must be corrected server-side for the deployed Web origin, including `Authorization`, `Content-Type`, `X-Storefront-Token`, required methods and any Socket.IO origin policy. No proxy workaround is appropriate.

## F. Payment, remote content and platform risks

* **Payment — BLOCKED for Web implementation:** Mobile checkout instantiates `razorpay_flutter` through `lib/features/payments/presentation/service/razorpay_service.dart`. The backend order create/verify/status paths are already represented and must remain authoritative. A Web adapter can be built only after confirming the supported Razorpay Web SDK loading/callback contract and public checkout key source. Never place a Razorpay secret or signature verification in the browser.
* **Remote content — VERIFIED:** endpoints for active/tab themes and section manifests exist and the app already has typed model/provider infrastructure (`lib/core/theme/`). Reuse it; unknown server component types must remain safely handled. The deployed remote schema remains `UNVERIFIED` without a non-destructive response capture.
* **Responsive design — PARTIALLY VERIFIED:** `ScreenUtilInit` preserves Web text scaling and reusable product/cart components remain shared. The desktop shell now has a navigation rail, persistent search/cart access and a 1440px content cap at the centralized 1024px breakpoint. Representative authenticated browser viewports remain blocked by API CORS.

## G. Proposed Web architecture

1. Add Flutter's standard Web target using the pinned toolchain, preserving Android/iOS platform folders.
2. Introduce narrowly scoped capability interfaces for startup/Firebase, session storage, payment checkout, map/location, file download, notifications, device security and app review. Select implementations through conditional imports or providers, not scattered `kIsWeb` branches.
3. Retain existing entities, DTOs, repositories, use cases, Dio client and GoRouter route names. Make only route data that must survive refresh URL-addressable.
4. Add a responsive app shell with centered desktop content, persistent search/cart access and adaptive product/cart/checkout layouts while preserving existing visual assets, color and typography systems.
5. Use a real PWA shell/manifest and cache only application assets and safe presentation resources. Treat prices, stock, cart validation, checkout, payment and order state as network-authoritative.

## H. Expected files/modules to change

* New `web/` target plus branded PWA metadata and a temporary splash-art fallback; an approved square icon remains a release gate.
* `lib/main.dart`, `lib/app.dart`, `lib/firebase_options.dart` and startup/platform adapters.
* `lib/core/storage/`, `lib/core/network/`, `lib/core/notifications/`, `lib/core/security/`, `lib/core/maps/`, `lib/core/utils/`.
* Payment adapter/service and the presentation call sites that depend on its SDK types.
* Responsive shell/shared widgets and focused route/adapter tests.
* `pubspec.yaml` only for verified platform replacements/configuration.

## I. Implementation sequence

1. Provision the pinned Flutter 3.41.9 toolchain, then run baseline `pub get`, analyze and tests.
2. Generate the current-toolchain Web target; do not hand-copy deprecated bootstrap files.
3. Refactor startup and native-only imports behind the smallest platform boundaries until Web compiles.
4. Replace Web-exposed dotenv configuration with a reviewed public define/config interface while retaining native compatibility.
5. Implement responsive shell, route refresh states, and PWA metadata/offline messaging.
6. Implement Web payment and notification adapters only from verified third-party/backend contracts.
7. Build, test and browser-smoke-test representative viewports; document all external configuration blockers.

## J. Risks and mitigations

| Risk | Mitigation |
|---|---|
| API CORS blocks all authenticated browser commerce | Backend must permit the final Web origin and preflight headers/methods; re-test before claiming browser connectivity. |
| `.env` leaks secrets into Web bundle | Do not package `.env` for Web; use public build definitions only. |
| Native plugins prevent compilation | Boundary-first migration with conditional imports and focused adapter tests. |
| Payment callback tampering | Server create/verify/status remains authoritative; no client-only paid state. |
| Firebase Web configuration absent | Keep the application honest and operational without Web push; enable only after legitimate configuration. |
| Mobile regression | Preserve native implementations and run Android/iOS checks when their SDKs are available. |

## Post-audit foundation work (build and smoke verified on 2026-09-08)

After this audit was recorded, the following small, source-level boundaries were implemented:

* `AppConfig` replaces dotenv reads with public `--dart-define` values, and `.env` was removed from Flutter assets. All mobile and Web builds now need explicitly supplied public endpoint configuration; no secret values were added.
* MapLibre hybrid-composition setup, certificate pinning, Firebase/FCM startup and Crashlytics reporting are conditionally selected so browsers do not execute native-only setup or claim unavailable services.
* Hive no longer requests an application-documents filesystem path on Web.
* The mobile Razorpay SDK is conditionally isolated. Web checkout is explicitly unavailable until a verified Web Checkout implementation is provided; the guard runs before creating a payment order and preserves existing server verification code.
* A `web/` target was added from the Flutter 3.41.9 template format (`flutter_bootstrap.js`) with Bakaloo metadata. The manifest/favicon use existing Bakaloo splash artwork temporarily because no approved square icon was found; the release build succeeds and the boot screen renders locally. PWA installation/service-worker behavior still needs an HTTPS host check.
* The shared platform surface now excludes direct `dart:io` imports except inside native-only conditional implementations. Profile avatar upload now takes bytes and a filename; invoice download keeps backend bytes and opens natively or starts a browser download through an explicit conditional boundary. The desktop shell adds a navigation rail, semantic search/cart controls, and a 1440px content cap at the centralized 1024px breakpoint. Flutter analyzer, tests, release build and local browser boot now provide verification evidence.
* Package metadata now confirms that the pinned `maplibre_gl` version advertises Web support, while pinned `geocoding` does not. The native geocoding fallback has therefore been conditionally isolated; browser location resolution retains the already-implemented backend Ola reverse-geocoding path.

`git diff --check` passed. `flutter pub get`, build generation, analyzer (with non-fatal legacy warnings), all 52 tests, and a release Web build passed on the pinned Flutter 3.41.9 SDK. A local browser smoke loaded the Bakaloo location gate at a clean `/home` path. Full authenticated commerce smoke remains blocked by the documented API CORS response and the production host rewrite/Firebase/payment gates.

## Baseline verification record

* `git status --short --branch`: clean `main...origin/main` after repository checkout.
* `.fvmrc`: requests Flutter `3.41.9`; an ignored `.fvm/flutter_sdk` copy was provisioned for this verification loop.
* `web/`: present with Flutter 3.41.9 template bootstrap and Bakaloo metadata; the standalone square icon remains an external release gate.
* `.env`: absent locally and ignored by `.gitignore`; its values were not read or printed.
* Existing focused tests plus responsive-breakpoint coverage: all 52 tests pass. The default analyzer still reports five pre-existing warnings, while `--no-fatal-warnings --no-fatal-infos` completes without errors.

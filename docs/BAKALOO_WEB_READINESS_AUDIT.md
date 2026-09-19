# Bakaloo Flutter Web/PWA readiness audit

**Audit date:** 2026-09-12
**Flutter workspace revision:** `aae571d7130c06c7e379eab66f8bd8bd4c7a0e0b` (`main`)
**Backend evidence revision:** `02c3aa7ccdfe8fb7f02d02b2e294ada69042f173` from `Shotlin/bakaloo-backend`
**Audit scope:** read-only inspection of the Flutter worktree and a temporary, read-only backend clone. This document does not certify any pre-existing uncommitted implementation.

## Pre-flight and workspace state

- The Git root is `C:/Users/sayan/Desktop/meat flutter web_app`; the task launch directory is its `bakaloo_flutter_website/` child.
- The active branch is `main`, tracking `origin/main`; the committed base is `aae571d` (`done`).
- The worktree is already materially dirty: 47 tracked files are modified and Web-specific adapters, `web/`, tests, tools, and several root-level handoff documents are untracked. These changes are preserved and must not be represented as a clean baseline.
- `.fvmrc` pins Flutter `3.41.9`; the local FVM SDK reports Flutter `3.41.9` and Dart `3.11.5`. System `flutter` and `dart` are absent from PATH, so all verification must use `.fvm/flutter_sdk/bin`.
- `pubspec.lock` exists. The project uses `flutter_test` plus targeted unit/widget tests; no end-to-end browser test suite was found.
- A valid-looking, but untracked, `web/` target exists. Its metadata initially contained legacy, non-Bakaloo branding, which was a release blocker.
- No `.env` file is present in this worktree. `pubspec.yaml` does not list `.env` as an asset, and `SETUP_GUIDE.md` now documents public `--dart-define` configuration instead of browser-bundled environment files.

## Flutter architecture

### Bootstrap, dependency injection, state, and persistence

- `lib/main.dart` initializes URL strategy, platform startup, Firebase startup, Hive, cache reconciliation, remote-layout cache reconciliation, diagnostics, and then a root `ProviderScope`.
- `lib/app.dart` is a Riverpod `ConsumerWidget` around `MaterialApp.router`; it uses `ScreenUtilInit`, a responsive design-size cap, theme state, notification initialization, route loading, availability, and app-version gates.
- `lib/core/di/providers.dart` provides `SecureStorageService`, `HiveService`, `Dio`, and Retrofit `ApiClient` through generated Riverpod providers. Feature folders follow data/domain/presentation boundaries, with repositories and use-cases over Retrofit/Dio data sources.
- Data-model generation is present (`freezed`, `json_serializable`, `retrofit_generator`, `riverpod_generator`); source definitions, not generated outputs, are the correct change points.
- Hive holds user, product, category, banner, order, theme/layout, search-history and related caches. `AppCacheManager` scopes and clears cache groups on backend/allocation changes. `flutter_secure_storage` holds access/refresh tokens; the current browser implication is that the plugin’s Web storage implementation must be accepted as the browser security boundary, with no authenticated response caching.

### Routing and deep links

- `lib/routing/app_router.dart` uses GoRouter and `StatefulShellRoute.indexedStack`, with independent home, orders, categories, and profile branch navigators.
- Auth redirection records protected deep-link intents and redirects unauthenticated visitors to the phone/OTP flow. Root, nested cart/checkout, product, category, order, tracking, address, profile, wallet, notification, and review routes exist.
- Product deep links accept both `/product/:productId` and `/products/:slug`; order detail and tracking are nested under `/orders/:orderId` and `/orders/:orderId/track`.
- An explicit unknown-route screen is configured. `configureUrlStrategy()` is called during startup, so a production Web host must rewrite application paths to `index.html`.

### Network, authentication, and session lifecycle

- `ApiConstants` obtains base/socket URLs from `AppConfig`. The existing adapter uses public `--dart-define` values (`BASE_URL`, `SOCKET_URL`, `WEB_BASE_URL`), falling back on Web to same-origin `/api/v1` and the browser origin. These values are public and must never contain credentials.
- Retrofit `ApiClient` declares auth, catalogue, cart, addresses, checkout/payment, orders, wallet, wishlist, reviews, refunds, notifications, and maps endpoints. Dio configuration uses authorization/refresh and connectivity interceptors.
- Auth is OTP-based: `/auth/send-otp`, `/auth/verify-otp`, and `/auth/refresh-token` are declared in Flutter. Auth state restores tokens from secure storage, persists the user in Hive, clears sensitive/local state on logout, and reconnects Socket.IO after token changes.
- Backend source confirms bearer JWT authentication (`@fastify/jwt`), access-token and refresh-token secrets, authenticated prehandlers, and optional cookie support. Browser implementation should use the established Authorization header model; no browser cookie-based redesign is warranted.

### Realtime, Firebase, maps, and payments

- `SocketService` connects with an auth token, uses websocket transport, reconnects, replays order-room joins, and disconnects/clears tracked rooms on logout. Backend Socket.IO verifies `handshake.auth.token` or bearer header, supports websocket/polling, and emits `order:status`, `rider:location:update`, `notification`, `theme:update`, `section:update`, store-status, and branding events. Customer order tracking is therefore contract-backed.
- Firebase startup is conditionally isolated. `firebase_options.dart` explicitly lacks Web options and Web startup intentionally avoids initialization; browser push/analytics/Crashlytics cannot be claimed until a legitimate Firebase Web configuration, messaging service worker, and VAPID strategy are supplied.
- The existing maps stack uses MapLibre, Geolocator, geocoding, an Android-only `location` SettingsClient adapter, and a backend Ola Maps proxy. Browser geolocation can use Geolocator with permission/denied states; Android settings resolution cannot be used on Web. The backend proxies Ola Maps specifically to keep its API key server-side.
- The backend creates Razorpay orders at `POST /api/v1/payments/create-order`, verifies at `POST /api/v1/payments/verify`, exposes `GET /api/v1/payments/status/:razorpayOrderId`, and independently finalizes via verified webhook/reconciliation. The untracked Web adapter calls Razorpay Standard Checkout and passes the callback only to the existing server verification path. It must never set a successful order state from the browser callback alone.

## Backend and browser contract

- `src/app.js` registers customer routes beneath `/api/v1`; the Flutter `ApiConstants` endpoint suffixes are therefore correct only when `BASE_URL` ends in `/api/v1` (or the same-origin fallback proxy provides it).
- The relevant backend modules are registered for auth, users, categories, products, cart, orders, payments, wallet, coupons, addresses, banners, tutorials, public themes, branding, wishlist, reviews, refunds, delivery, notifications, app version, store status, allocation, and Ola Maps.
- CORS is implemented in `src/plugins/cors.plugin.js`. It allows configured origins plus all `bakaloo.in`, `shotlin.in`, and `vercel.app` hosts; it enables credentials, Authorization, Content-Type, `X-Requested-With`, and `X-Shop-Id`, and supports GET/POST/PUT/PATCH/DELETE/OPTIONS. This is not a wildcard policy, but the hard-coded `vercel.app`/domain suffix allowance should be reviewed by backend owners before production.
- Socket.IO uses `CORS_ORIGINS` only, unlike HTTP CORS. A production Web origin must be explicitly added to `CORS_ORIGINS`, including preview/staging origins as intended. Otherwise HTTP may succeed while realtime fails.
- Swagger is available at `/documentation` only when `ENABLE_SWAGGER` is true; its declared server is localhost and should not be treated as a production OpenAPI contract.
- Backend authenticated responses are marked `Cache-Control: no-store, no-cache, must-revalidate, private`. This is the correct server-side complement to browser cache discipline.

## Web-compatibility matrix

| Capability/package | Finding from project/source | Web classification | Required handling |
| --- | --- | --- | --- |
| Dio, Retrofit, Riverpod, GoRouter | Shared Dart implementation; routes use browser URL strategy. | B — configuration | Use public base URL/origin and host rewrite. |
| `http_certificate_pinning` | Native pinning adapter and Web no-op files exist. | D — conditional import | Retain pinning on mobile; no pinning attempt in browser. |
| `razorpay_flutter` | Native adapter retained; Web Standard Checkout bridge exists. | F — replacement | Keep server create/verify/status flow and use only Razorpay public key. |
| `flutter_secure_storage` | Used for tokens. | B — Web implementation | Treat browser storage as less secure than OS keychain; clear on logout and never cache protected API payloads. |
| Hive / `hive_flutter` | Used for cache and session-adjacent state; path adapters exist. | B — Web implementation | Avoid private-data cache leakage; preserve cache version/scope invalidation. |
| Firebase core/messaging/analytics/Crashlytics | Web Firebase deliberately unconfigured. | E — feature gate | Do not initialize/register Web FCM until real config, VAPID and service worker exist. |
| `flutter_local_notifications` | Native notification startup is conditionally isolated. | G — native-only path | Use Web Push only after legitimate Firebase configuration; otherwise retain in-app notifications. |
| MapLibre / Ola Maps | Interactive map and server-side Ola proxy are used. | C/E — adapter or gate | Verify actual map plugin/browser path; retain static/backend-proxied address selection and do not expose Ola keys. |
| Geolocator/geocoding | Used throughout addresses/location. | B/E — browser permissions | Provide browser permission/denied/unavailable UX; never invoke Android settings resolution. |
| `location` | Used for Android SettingsClient. | G — native-only path | Conditional native resolver; Web uses browser guidance. |
| `flutter_jailbreak_detection`, screenshot prevention | Native method channel/root detection adapters exist. | D/G — conditional/no-op | Preserve mobile protections; do not invoke on Web. |
| `open_file`, `path_provider` | Native invoice path; Web Blob download adapter present. | C — Web adapter | Browser download/open behavior only. |
| `local_auth`, `in_app_review` | Platform adapters exist. | E — feature gate | Hide/replace where no meaningful browser equivalent. |
| `speech_to_text`, YouTube player | Imported by feature screens. | B/E — verify per feature | Browser test the actual plugin route and show unavailable states when unsupported. |
| `share_plus`, `url_launcher`, `connectivity_plus` | Used in product/profile and connectivity state. | B — Web implementation | Verify browser fallback and never infer connectivity as transaction success. |
| `wakelock_plus` | Used on tracking. | E — gate | Browser support must be capability-checked; tracking must function without it. |
| `socket_io_client` | Token auth, reconnection and room replay implemented. | B — configuration | Explicit Socket.IO CORS origin and live browser test required. |

## Security risks and required adapters

1. **Branding correctness blocker:** the existing untracked Web target and several root-level documents initially contained legacy, non-Bakaloo naming. Public Web metadata must use Bakaloo before release.
2. **No secret exposure:** `AppConfig` correctly describes dart defines as public, but build commands must omit all private backend, Firebase Admin, Razorpay secret, JWT, database, SMTP, and Cloudinary secret values.
3. **CORS/socket gate:** browser API and Socket.IO use cannot be verified against production until the deployed API accepts the final HTTPS Web origin and Socket.IO `CORS_ORIGINS` does likewise.
4. **Firebase Web gate:** there are no valid Web options, VAPID key, or messaging worker. Native Firebase behavior must stay isolated; Web notification claims are blocked.
5. **Payments gate:** server verification is correctly authoritative, but an owner-authorized Razorpay test transaction and allowed checkout origin are necessary to verify Web payment end to end.
6. **Host gate:** the production host must provide HTTPS, SPA fallback/rewrite, and a same-origin API proxy or an explicit CORS configuration.

## Existing Web target status

An untracked `web/` directory contains `index.html`, manifest, icon assets, and a Razorpay bridge. Its public metadata has been corrected to Bakaloo, but browser installability/offline behavior has not been independently verified in this audit. The target must be tested with the FVM-pinned SDK after the implementation plan is recorded.

## Audit conclusion

The shared Flutter architecture and backend contracts are suitable for a Web/PWA adaptation without a rewrite. The implementation should use shared repositories/state and small platform boundaries, preserve mobile implementations, and complete contract-driven verification. External configuration—not fabricated source-side behavior—is required for Firebase push, production CORS/Socket.IO, a real checkout transaction, and final hosting.

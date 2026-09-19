# Bakaloo Web/PWA handoff

**Date:** 2026-09-08
**Baseline:** `main` at `aae571d7130c06c7e379eab66f8bd8bd4c7a0e0b`
**Scope:** source implementation, audit, verification and release handoff only. No deployment, push or merge was performed.

## Delivered

- Flutter Web target based on the pinned Flutter 3.41.9 template, with Bakaloo title/metadata and an installable manifest. The manifest temporarily uses existing Bakaloo splash artwork; approved square regular/maskable icons are still required.
- Public build configuration through `BASE_URL`, `SOCKET_URL` and `WEB_BASE_URL` `--dart-define` values. `.env` is not packaged as a Flutter asset.
- Clean browser path URLs through Flutter's path URL strategy, shared GoRouter routes, and a controlled unknown-route screen.
- Responsive app shell with a 1024px desktop breakpoint, persistent desktop search/cart access, a navigation rail and a 1440px content cap; mobile bottom navigation remains below the breakpoint.
- Conditional platform boundaries for native map startup, certificate pinning, Firebase/FCM/Crashlytics startup, Hive paths, device security/authentication/review, reverse geocoding, invoice opening and Razorpay checkout.
- Browser-safe profile avatar bytes upload and invoice Blob download. Web payment uses Razorpay Standard Checkout behind the existing server create/verify/status flow; the browser never treats a client callback as confirmed payment success.
- A local preview server at `tools/web-server.mjs` with safe SPA fallback and a fixed-upstream development proxy. It is not a replacement for production host routing or API CORS.
- Focused responsive-breakpoint tests and source fixes required to produce the Web build.

## Verification evidence

All commands were run with the ignored `.fvm/flutter_sdk` Flutter 3.41.9 SDK. The workspace path contains spaces, so a temporary `X:` drive alias was used for Flutter commands to avoid a native build-hook path parsing issue.

| Check | Result |
|---|---|
| `flutter pub get` | PASS |
| `flutter pub run build_runner build --delete-conflicting-outputs` | PASS; 72 generated outputs |
| `flutter analyze --no-fatal-warnings --no-fatal-infos` | PASS; no analyzer errors |
| `flutter test` | PASS; all 52 tests |
| `flutter build web --release` | PASS; `build/web` produced |
| Local browser boot / `/home` refresh | PASS; the local server provides the SPA fallback and Bakaloo boots at the clean path |
| Fixed-upstream local API proxy | PASS; contract test verifies fixed target, header hygiene and no cache for API responses |
| `git diff --check` | PASS |

The default analyzer command still exits non-zero because the baseline project has five pre-existing warnings (unused elements/import/parameters). They are recorded rather than changed as unrelated cleanup.

## Release gates and external follow-up

1. **API CORS:** the expected API returned no `Access-Control-Allow-Origin` for an Origin-bearing GET, and its OPTIONS preflight returned HTTP 404. The backend must allow the final Web origin, required headers/methods and the Socket.IO origin.
2. **SPA host rewrites:** the production host must return `index.html` for unknown application paths so `/products/:slug`, `/orders/:orderId`, `/cart/checkout` and similar clean URLs survive refresh/direct navigation. Do not switch back to hash routing.
3. **Firebase Web:** supply real Firebase Web options, VAPID strategy and messaging service worker before enabling Web push or analytics/crash reporting.
4. **Razorpay Web:** run one merchant-authorized test transaction on the final domain and confirm domain allowlisting, public key source, server verification and recovery behavior. Never place a secret or signature verification in the browser.
5. **HTTPS installability:** validate manifest/service-worker registration, permissions and offline cache policy on the final HTTPS host. Keep prices, stock, cart, checkout, payment and order state network-authoritative.

See [WEB_READINESS_AUDIT.md](WEB_READINESS_AUDIT.md), [WEB_MIGRATION_STATUS.md](WEB_MIGRATION_STATUS.md) and [WEB_DEPLOYMENT_REQUIREMENTS.md](WEB_DEPLOYMENT_REQUIREMENTS.md) for the evidence trail and exact host requirements. Razorpay's Standard Checkout lifecycle is documented in its official Web integration guide.

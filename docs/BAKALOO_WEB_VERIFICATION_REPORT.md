# Bakaloo Web / PWA Verification Report

**Date:** 2026-09-12
**Toolchain:** Flutter 3.41.9 / Dart 3.11.5 (repository FVM SDK)

## Scope and baseline

The repository was already a dirty, in-progress web migration. Existing work was preserved. This report covers the Bakaloo web-release corrections and validation performed on top of that baseline; it does not assert that every legacy source identifier or asset in the repository has been replaced.

## Implemented release-facing corrections

- Updated browser document and manifest branding to Bakaloo.
- Aligned favicon and Apple touch-icon metadata with the same Bakaloo artwork; no generic legacy `web/icons/Icon-*` path is referenced by the document.
- Aligned the Razorpay web bridge names between Dart and `web/checkout-bridge.js`.
- Replaced primary web/auth/splash/offline/location references with existing Bakaloo artwork and labels.
- Removed the retired brand from runtime strings, native app labels, and the older handoff notes; visible logo slots without an approved standalone wordmark now use a Bakaloo text fallback.
- Normalized remaining brand-specific red literals in cart, product, profile, address, store, and browser theme surfaces to the shared Bakaloo purple palette; semantic error/out-of-stock reds remain separate.
- Added an explicit Bakaloo app-shell service worker registration with network-first JavaScript bundles, cache-first static assets, navigation fallback, and API/Socket.IO cache bypasses. A custom Flutter bootstrap template omits the deprecated generated-worker registration, avoiding a scope race; Flutter’s generated file remains present only as an unused build artifact.
- Added global keyboard focus and hover overlays to the app theme so Web and desktop controls remain visibly discoverable against light commerce surfaces.
- Converted the high-frequency home search, delivery-address, and notification controls from gesture-only regions to semantic, keyboard-focusable Material interactions.
- Wired the existing offline browsing state into the availability overlay with an explicit “Browse saved items” action; retry/check remain network checks, and the copy makes clear that fresh stock, delivery, checkout, and payment still require connectivity.
- Updated Socket.IO transport negotiation to prefer WebSocket with the backend-supported polling fallback, while retaining the existing bearer-token handshake, reconnect, and tracked-order room replay.
- Hardened the checked-in Web preview/proxy with a least-privilege `Permissions-Policy` (same-origin geolocation/microphone, camera denied) and regression coverage for the response header.
- Expanded responsive breakpoint regression coverage across the brief’s reference widths (360, 390, 430, 768, 1024, 1280, 1440, and 1920 px).
- Added explicit `/` → splash and `/checkout` → `/cart/checkout` redirects so root launches and public checkout deep links enter the real auth-guarded flow.
- Kept Razorpay order payments in backend reconciliation when the browser returns a partial success payload or `/verify` rejects/fails in transit; the client no longer unlocks the cart on an unconfirmed result and now polls the existing authenticated status endpoint before cancelling or confirming.
- Made cancellation reconciliation await a backend `paymentConfirmed` result before publishing a failure/cancel state, closing the late-capture race where success could otherwise be overwritten by a contradictory error.
- Hardened splash session restoration against undecodable persisted access tokens; the unusable session is cleared and routed through the normal public auth flow instead of leaving the PWA stuck on splash.
- Removed the unserviceable-location screen's fake "notify me" success snackbar; it now shows an honest informational state until the backend exposes an area-alert signup contract, while retaining an optional callback seam for a real integration.
- Kept tutorials on the real public `/api/v1/tutorials` contract and added a semantic play label to each tutorial tile; the Web player uses the package's YouTube iframe implementation rather than an external redirect.
- Replaced the address picker's blank static-map failure canvas with a visible "Map unavailable right now" retry state, so a failed map image cannot look like a valid map preview.
- Added a Web-only opt-in gate for dashboard-controlled campaign artwork (`ALLOW_REMOTE_MARKETING_ASSETS=true`). Live catalogue/product sections remain available, while unreviewed remote banners, mosaics, fee strips, and animations are suppressed by default so legacy campaign imagery cannot leak into the Bakaloo shell.
- Bumped the app-shell worker cache version after the Web branding/configuration changes so existing PWA clients retire stale bootstrap and shell files during activation.
- Added the readiness audit and implementation plan that describe API, auth, socket, payment, PWA, deployment, and release gates.
- Corrected `SETUP_GUIDE.md` so Web operators use public dart defines and do not reintroduce a bundled `.env` file.

An approved standalone Bakaloo wordmark/app-icon asset was not identified in the supplied tree. The manifest/favicon now reference the existing Bakaloo splash artwork as a temporary branded fallback; the brand owner must supply a square icon and wordmark before production release.

Several tracked legacy image files remain physically under `assets/images/`, but the explicit pubspec list now excludes them from the Web asset manifest. Untracked generated files under `web/icons/` and `web/favicon.png` also remain unreferenced and should be replaced with the approved square Bakaloo assets or removed during the final asset-owner cleanup; no tracked binary was deleted during this pass.

## Automated verification

| Check | Result | Notes |
| --- | --- | --- |
| `flutter pub get` | Pass | Used the repository FVM SDK. |
| `flutter test` | Pass | 53 tests passed when invoked through a temporary `Z:` drive alias. The literal workspace path contains spaces and triggers an upstream native-assets shell-hook failure before discovery. |
| `flutter test test/core/layout/responsive_breakpoints_test.dart` | Pass | 3 focused tests passed, covering all representative mobile/tablet/desktop reference widths. |
| `node --test tools/checkout-bridge.test.mjs tools/web-server.test.mjs` | Pass | 11 tests passed, including duplicate/ambiguous Razorpay callbacks, verification-recovery source contract, splash-session recovery, honest unserviceable-location messaging, Web campaign-artwork gating, root SPA fallback, public metadata, service-worker registration/cache boundaries, Socket.IO transport/auth configuration, permissions policy, and legacy-brand exclusion. |
| `flutter analyze` | Warnings only | No compile errors; the normal command remains non-zero because of existing analyzer findings. |
| `flutter analyze --no-fatal-warnings --no-fatal-infos` | Pass | 241 non-fatal project warnings and infos, including generated-code findings. |
| `flutter build web --release` | Pass | Final JS web bundle built successfully. |
| `flutter build apk --debug` | Blocked | Flutter reached the Android build step, but this host has no Android SDK configured (`No Android SDK found; set ANDROID_HOME`). Android source was not changed by the Web verification pass. |
| `git diff --check` | Pass | No whitespace errors. |

Post-build asset inspection found no retired-brand filenames in `build/web`; the tracked legacy source images remain on disk only and are excluded by the explicit Web asset list. The custom service worker is included in the Web source and release bundle, and the generated `flutter_bootstrap.js` invokes `_flutter.loader.load()` without Flutter service-worker settings; install/offline behavior still requires an HTTPS/localhost browser deployment to verify.

The release build also reported Wasm dry-run incompatibilities in `flutter_secure_storage_web` and `location_web`, plus a tree-shaken icon-font warning. These do not prevent the standard JavaScript release build, but WebAssembly is not ready to claim as supported.

## Browser smoke test

The checked-in preview server was exercised in both a clean browser origin and the previously cached origin after the release build. Live catalogue data loaded through the fixed upstream proxy, the Web campaign-artwork gate prevented the backend's unreviewed legacy strip/mosaic imagery from appearing in the Bakaloo shell, and the v2 worker cache replacement kept the cached-origin reload stable. Additional direct-route and refresh checks are recorded below.

**Coverage:** Browser screenshots were captured at 390×844 (mobile), 768×1024 (tablet-width adaptive shell), and 1440×900 (desktop shell/navigation rail), plus a cached-origin 1280px-class reload. Direct `/home` startup, direct `/products/fresh-fish` (honest product-not-found state), direct `/unknown-route` (controlled unavailable state), refresh of both the home and unknown deep link, and unauthenticated `/cart` and `/checkout` redirects to `/auth/phone` were exercised. The remaining reference widths (360, 430, 1024, 1280, and 1920 px) are covered by the passing responsive unit tests but were not separately screenshot-captured in this pass.

No authenticated checkout, OTP, payment, realtime, map, or notification flow was completed against a verified production-equivalent backend. The nested payment URL now resolves to the real checkout screen; missing onboarding/settings capabilities expose controlled unavailable states rather than fake placeholder screens. Payment success must remain server-verified. Offline cached browsing is wired but still needs an HTTPS browser run with populated local caches to validate the visual replay path.

Mobile preservation is source-level and Web/build-verified in this environment; Android compilation is blocked by the missing SDK noted above, and iOS compilation requires a macOS/Xcode host.

## Release blockers / required owner confirmation

1. Confirm the final frontend origin in both backend HTTP CORS and Socket.IO CORS configuration.
2. Configure production hosting with an SPA fallback to `index.html`, HTTPS, and appropriate static caching.
3. Supply the approved Bakaloo web icon, wordmark, browser visuals, and legal/marketing copy; only then opt in reviewed dashboard campaign artwork with `ALLOW_REMOTE_MARKETING_ASSETS=true`.
4. Provide real Firebase Web configuration, VAPID/service-worker setup, and test browser push permission/delivery.
5. Execute Razorpay test-mode payment and server-side verification on the final allowed domain.
6. Validate OTP, token refresh/logout, protected routes, sockets (including the polling fallback), maps, and payment recovery against the deployed API.
7. If area-availability alerts are required, add and validate a real customer signup endpoint before wiring the screen's optional notification callback.

## Safe run/build examples

Public endpoints may be supplied at build/run time; do not place private credentials in browser defines:

```powershell
.\.fvm\flutter_sdk\bin\flutter.bat run -d chrome --dart-define=BASE_URL=https://api.bakaloo.in/api/v1 --dart-define=SOCKET_URL=https://api.bakaloo.in --dart-define=WEB_BASE_URL=https://YOUR_WEB_ORIGIN

.\.fvm\flutter_sdk\bin\flutter.bat build web --release --dart-define=BASE_URL=https://api.bakaloo.in/api/v1 --dart-define=SOCKET_URL=https://api.bakaloo.in --dart-define=WEB_BASE_URL=https://YOUR_WEB_ORIGIN
```

The origins above are public configuration inputs to validate with the infrastructure owner; they are not evidence of a deployed, working production contract.

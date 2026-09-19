# Bakaloo Flutter Web/PWA implementation plan

**Basis:** `docs/BAKALOO_WEB_READINESS_AUDIT.md` (2026-09-12).
**Guardrail:** The existing worktree is dirty. Preserve unrelated and pre-existing changes; make focused, reviewable updates only.

## Phase 2 — establish a release-safe Web foundation

1. Inspect the existing untracked Web target and platform adapters against the audited contracts; retain native implementations through conditional imports.
2. Replace all legacy Web/PWA text and metadata with the verified Bakaloo identity and existing app assets. Do not introduce new branding.
3. Keep public configuration centralized in `AppConfig`; document `BASE_URL`, `SOCKET_URL`, and `WEB_BASE_URL` as public dart defines. Ensure no `.env` or private value is packaged into Web.
4. Build with the pinned FVM SDK and resolve only root-cause Web compiler failures. Do not delete major customer features to compile.

**Phase gate:** Web starts, the router initializes, platform imports are isolated, and mobile code remains intact.

## Phase 3 — responsive application shell

1. Validate the existing responsive breakpoint primitives at 360–390, 430, 768, 1024, 1280, 1440, and 1920 CSS-pixel widths.
2. Preserve mobile bottom navigation and introduce constrained desktop layout/navigation only where already implemented in the shared shell.
3. Review home, categories, search, product detail, cart, checkout, orders/tracking, wallet and profile for overflow, stretched phone UI, focus order, and visible keyboard focus.
4. Keep product imagery aspect-safe and use only the existing media/Cloudinary logic established by the application.

## Phase 4 — commerce core and browser adapters

1. Verify live API behavior only after safe access is available: session, home, catalogue, category, search, product, wishlist, cart, and addresses.
2. Keep address/location flows browser-appropriate: permission request after explicit action, denied/unavailable guidance, and no Android SettingsClient behavior.
3. Keep native-only root detection, local auth, certificate pinning, local notifications, invoice opening, and native map assumptions behind their adapters.
4. Verify Socket.IO with the actual backend token/auth payload and reconnect/room replay behavior. Configure the final Web origin in both HTTP CORS and Socket.IO `CORS_ORIGINS` before declaring realtime functional.

## Phase 5 — checkout and post-purchase

1. Preserve the backend-controlled payment sequence: create payment order → Razorpay Standard Checkout callback → server verification/status → confirmed backend order state.
2. Verify failure, cancel, timeout, and ambiguous-status handling. A client callback is never a success state.
3. Verify orders, tracking, reorder, reviews, refunds, wallet, support, profile, and in-app notifications against backend-backed states where credentials permit.
4. Do not claim Firebase browser push until real Firebase Web options, VAPID configuration, and a messaging service worker are supplied.

## Phase 6 — PWA, security, and verification

1. Validate manifest, Bakaloo icons, start URL, colors, installability, bootstrap/service worker behavior, and offline shell behavior over HTTPS.
2. Update setup documentation with exact FVM commands and public configuration. Document SPA rewrites, HTTPS, API CORS, Socket.IO origins, Razorpay public-key/origin requirements, and Firebase Web requirements.
3. Run `flutter pub get`, generation only if source definitions changed, `flutter analyze`, `flutter test`, and `flutter build web --release` using the FVM SDK. Report all warnings/failures without masking them.
4. Browser-smoke the app at representative widths, direct links, refresh/back/forward, unknown routes, offline/reconnect, keyboard access, manifest, and available real backend flows.
5. Produce `docs/BAKALOO_WEB_VERIFICATION_REPORT.md` with exact evidence and separate implemented/compiled/tested/browser-verified/backend-verified/blocked states.

## External release gates

- A final HTTPS Bakaloo Web origin must be explicitly configured for backend HTTP CORS and Socket.IO CORS.
- The production host must rewrite unknown application routes to `index.html`.
- Firebase Web options, VAPID key, and Firebase messaging worker must be supplied before Web push is enabled.
- A merchant-authorized Razorpay Web test transaction and final checkout-domain allowlisting are required before payment can be declared browser-verified.
- No deployment, DNS, backend production mutation, push, or merge is in scope.

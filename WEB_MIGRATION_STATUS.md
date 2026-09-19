# Bakaloo Web/PWA migration status

**Last updated:** 2026-09-08

| Phase | Status | Completed / evidence | Blockers / next work |
|---|---|---|---|
| 0. Baseline discovery | COMPLETE | Repository restored from the supplied source; clean `main` at `aae571d`. Project metadata, pubspec, platform folders, route/API/core feature structure and assets inspected. | None. |
| 1. Web-readiness audit | COMPLETE | `WEB_READINESS_AUDIT.md` created with architecture, contract, security, CORS and compatibility evidence. | External service configuration constraints remain recorded. |
| 2. Web foundation | COMPLETE — BUILD VERIFIED | Added a Flutter 3.41.9-template-compatible `web/` target, validated manifest JSON, wired public Bakaloo metadata and replaced bundled dotenv reads with public `--dart-define` configuration. Native map startup, certificate pinning, Firebase/FCM startup, Hive paths and mobile Razorpay are conditionally isolated. `flutter pub get`, code generation, release Web build and `git diff --check` pass. | Release still requires an approved square PWA icon plus the external API/Firebase/payment prerequisites listed below. |
| 3. Responsive shell | IN PROGRESS — PARTIALLY VERIFIED | Added centralized 600px/1024px/1440px responsive primitives. At desktop width, `AppShell` now uses a navigation rail, persistent semantic search/cart controls, and a centered content cap; existing mobile bottom navigation remains unchanged below the breakpoint. | Representative product, cart, checkout and detail viewports still need browser inspection after backend access is enabled. |
| 4–6. Commerce and transactions | IN PROGRESS — PARTIALLY VERIFIED | Web now uses Razorpay's Standard Checkout script behind the existing server create/verify/status flow. The browser passes a matching checkout callback to the server verifier; it never treats a client callback as payment success. | A merchant-authorized test payment and final-domain allowlisting remain required before release. |
| 7. Firebase / notifications | BLOCKED — EXTERNAL CONFIG | Firebase Web options intentionally remain disabled until a real project configuration, VAPID key and service worker are supplied. | Legitimate Firebase Web configuration and VAPID strategy required. |
| 8. URLs / deep links | COMPLETE — LOCAL VERIFIED | Added a controlled GoRouter invalid-route screen and enabled Flutter path URL strategy. The included local preview server serves static assets, rewrites app paths such as `/home` to `index.html`, and proxies only the fixed backend `/api/v1` and Socket.IO paths. | Production host must provide an equivalent rewrite/proxy or configured API CORS; the local server is not a production deployment. |
| 9. PWA | IN PROGRESS — PARTIALLY VERIFIED | Manifest and current Flutter bootstrap reference added; manifest JSON parses; existing Bakaloo splash artwork is used as a temporary icon fallback; release build succeeds and boot screen renders locally. | Approved square icons, browser installability, service-worker registration and offline policy need a real HTTPS host check. |
| 10–15. Content, states, accessibility, performance, security, mobile protection | IN PROGRESS — PARTIALLY VERIFIED | Browser-safe adapters now cover native map startup, certificate pinning, root detection, local-auth gate, app-review prompt, local invoice opening, Hive path resolution, and native-only reverse geocoding. Browser reverse geocoding remains on the existing backend Ola proxy. Invoice downloads retain backend bytes and use a browser Blob download on Web. Web retains user text scaling rather than applying the mobile cap. | Platform implementations and responsive/accessibility behavior require compiler and browser verification. |
| 16–18. Tests, release build, browser smoke | COMPLETE — EVIDENCE RECORDED | `flutter test` passes all 52 tests; `flutter analyze --no-fatal-warnings --no-fatal-infos` reports no errors; release Web build succeeds; local `/home` reload and fixed-upstream API proxy tests pass. Guests can browse without granting location; location is requested when they explicitly use location-sensitive delivery features. | Default analyzer still exits non-zero on five pre-existing unused-element/import/parameter warnings; a merchant-authorized payment and final-host browser smoke remain required. |
| 19. Iterative fix loop | COMPLETE — SOURCE FIXES VERIFIED | Fixed code-generation import ordering, nullable Razorpay callback code, missing wallet input formatter import, platform-only imports/startup, and hash URL routing; reran analyzer, tests and release build. | Remaining work is external configuration, not a safe source-only workaround. |
| Final handoff | COMPLETE | This status, `WEB_READINESS_AUDIT.md`, `WEB_DEPLOYMENT_REQUIREMENTS.md` and `WEB_PWA_HANDOFF.md` record implementation scope, evidence and release gates. | No deployment, push or merge performed. |

## Current external blockers

1. **BLOCKED — backend CORS required:** the supplied expected API origin returns no `Access-Control-Allow-Origin` to an Origin-bearing safe GET and returns 404 to its preflight OPTIONS request.
2. **BLOCKED — Firebase Web configuration required:** no valid Firebase Web options/VAPID/service worker are present.
3. **RELEASE GATE — payment production verification required:** the Web Checkout bridge is implemented, but a merchant-authorized test transaction and final-domain allowlisting are still required.
4. **RELEASE GATE — SPA host rewrite:** the production host must serve `index.html` for unknown application paths so clean-path refresh/direct-link behavior works.

The pinned Flutter 3.41.9 SDK was provisioned in the ignored `.fvm/` directory for verification. Because the workspace path contains spaces, commands were run through a temporary drive alias; this is an environment workaround only and is not part of the app.

## Deployment handoff preparation

`WEB_DEPLOYMENT_REQUIREMENTS.md` records build-time public configuration, GoRouter path-URL rewrite behavior, the observed CORS failure, Firebase Web prerequisites, host-header guidance, and the local-preview boundary. It does not deploy or modify infrastructure.

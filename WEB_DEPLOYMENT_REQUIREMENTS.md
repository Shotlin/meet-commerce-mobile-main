# Bakaloo Web/PWA deployment requirements

This document is a deployment handoff requirement, not authorization to deploy or modify infrastructure.

## Build configuration

The application now obtains public client configuration from `--dart-define` values:

* `BASE_URL`
* `SOCKET_URL`
* `WEB_BASE_URL`

Use only confirmed public URLs. Values compiled into a Flutter Web build are public. Do not supply backend secrets, Razorpay secrets, Firebase service-account credentials, database credentials, administrator tokens, or other private material.

`BASE_URL` is expected by the project to be `https://api.fc.opslin.com/api/v1`, but the repository does not verify the deployed value. Confirm it with the backend owner before release.

## Browser routing

The host must serve existing static files normally and rewrite unknown application routes to `index.html` with HTTP 200. This is required for direct navigation and refresh of routes such as:

* `/products/:slug`
* `/orders/:orderId`
* `/orders/:orderId/track`
* `/cart/checkout`

Do not use a hash-routing workaround. The Web application uses GoRouter path URLs.

## Local preview only

For this workspace, run `node tools/web-server.mjs` after `flutter build web --release`, then open `http://127.0.0.1:8080/home`. It provides the required local SPA rewrite and exposes only a fixed `/api/v1` and Socket.IO proxy target. It rejects arbitrary proxy destinations and strips browser origin, cookie and forwarded headers before proxying.

This is a local development convenience, not production infrastructure. The release host must implement the routing/proxy policy itself, or the API owner must configure the final Web origin under the CORS requirements below.

## Required API CORS change

For the finalized Bakaloo Web origin, the API must:

* return `Access-Control-Allow-Origin` for that specific origin;
* answer OPTIONS preflight requests with an allowed status and method list;
* permit request headers used by the client: `Authorization`, `Content-Type`, and `X-Storefront-Token`;
* allow the required HTTP methods used by the verified API client;
* configure the Socket.IO origin policy for that same origin.

Audit evidence on 2026-09-08: an Origin-bearing safe GET to the supplied expected API base returned no `Access-Control-Allow-Origin`; the matching OPTIONS request returned HTTP 404. Do not use a browser-security bypass or public CORS proxy.

## Firebase and notifications

Web push must remain disabled until all of the following are supplied by the legitimate Firebase project owner:

* Firebase Web application configuration;
* VAPID public key strategy;
* messaging service worker;
* token registration and logout-cleanup validation;
* foreground, denied-permission and unsupported-browser behavior tests.

## Recommended host headers

Adapt these to the actual deployed asset, API, Socket.IO, Cloudinary and Firebase origins; do not enable origins that are not actually required.

* `Content-Security-Policy` with restrictive `default-src 'self'`, explicit `connect-src`, `img-src`, `script-src`, and `frame-ancestors` directives.
* `X-Content-Type-Options: nosniff`
* `Referrer-Policy: strict-origin-when-cross-origin`
* `Permissions-Policy: geolocation=(self)` only if browser location remains enabled for the final origin.
* `frame-ancestors 'none'` in CSP unless embedding Bakaloo is an explicit requirement.

Do not cache authenticated API responses, cart state, checkout, prices, stock, coupon validation, payment, wallet, or order tracking as offline-authoritative data. Cache only the application shell and safe static assets.

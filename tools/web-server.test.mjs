import { test } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { mkdtemp, writeFile, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createWebServer } from './web-server.mjs';

const listen = server => new Promise(resolve => server.listen(0, '127.0.0.1', () => resolve(`http://127.0.0.1:${server.address().port}`)));

test('public Web metadata is branded for Bakaloo and contains no retired brand', async () => {
  const manifest = JSON.parse(await readFile(new URL('../web/manifest.json', import.meta.url), 'utf8'));
  const index = await readFile(new URL('../web/index.html', import.meta.url), 'utf8');
  const serviceWorker = await readFile(new URL('../web/bakaloo_service_worker.js', import.meta.url), 'utf8');
  const bootstrap = await readFile(new URL('../web/flutter_bootstrap.js', import.meta.url), 'utf8');
  assert.equal(manifest.name, 'Bakaloo');
  assert.equal(manifest.short_name, 'Bakaloo');
  assert.match(manifest.description, /Bakaloo/);
  assert.match(index, /<title>Bakaloo<\/title>/);
  assert.match(index, /apple-touch-icon[^>]+bakaloo-splash-screen\.png/);
  assert.doesNotMatch(index, /icons\/Icon-/);
  const retiredBrand = ['Fresh', 'Cuts'].join('');
  assert.doesNotMatch(
    `${JSON.stringify(manifest)}\n${index}`,
    new RegExp(retiredBrand, 'i'),
  );
  assert.match(index, /bakaloo_service_worker\.js/);
  assert.match(serviceWorker, /CACHE_NAME = `\$\{CACHE_PREFIX\}v2`/);
  assert.doesNotMatch(bootstrap, /serviceWorkerSettings\s*:/);
  assert.match(serviceWorker, /self\.addEventListener\('fetch'/);
  assert.match(serviceWorker, /url\.pathname\.includes\('\/api\/'\)/);
  assert.match(serviceWorker, /url\.pathname\.includes\('\/socket\.io\/'\)/);
  assert.match(serviceWorker, /url\.pathname\.endsWith\('\.js'\)/);
});

test('Web campaign artwork stays opt-in until branded assets are approved', async () => {
  const config = await readFile(
    new URL('../lib/core/config/app_config.dart', import.meta.url),
    'utf8',
  );
  const sections = await readFile(
    new URL('../lib/features/home/presentation/widgets/dynamic_home_sections.dart', import.meta.url),
    'utf8',
  );
  assert.match(config, /ALLOW_REMOTE_MARKETING_ASSETS/);
  assert.match(config, /!kIsWeb \|\| _allowRemoteMarketingAssets/);
  assert.match(sections, /SectionType\.seasonalMosaic/);
  assert.match(sections, /SectionType\.feeStrip/);
  assert.match(sections, /SectionType\.customBanner/);
  assert.match(sections, /AppConfig\.allowRemoteMarketingAssets/);
});

test('Socket.IO Web config prefers WebSocket with polling fallback and auth', async () => {
  const source = await readFile(
    new URL('../lib/core/socket/socket_service.dart', import.meta.url),
    'utf8',
  );
  assert.match(source, /setTransports\(<String>\['websocket', 'polling'\]\)/);
  assert.match(source, /setAuth\(<String, dynamic>\{'token': accessToken\}\)/);
});

test('payment verification failures stay reconcilable before the cart unlocks', async () => {
  const source = await readFile(
    new URL('../lib/features/payments/presentation/providers/payment_provider.dart', import.meta.url),
    'utf8',
  );
  // A missing callback field and a rejected /verify request are both
  // ambiguous until the backend status endpoint has spoken. Guard this
  // invariant at the source-contract level so a future cleanup cannot
  // reintroduce the paid-but-shows-failed race.
  assert.match(
    source,
    /if \(paymentId == null \|\| signature == null\) \{[\s\S]*?_beginPendingConfirmation\([\s\S]*?orderId: orderId,[\s\S]*?razorpayOrderId: razorpayOrderId,/,
  );
  assert.match(
    source,
    /result\.fold\([\s\S]*?\(failure\) \{[\s\S]*?_beginPendingConfirmation\([\s\S]*?orderId: orderId,[\s\S]*?razorpayOrderId: razorpayOrderId,/,
  );
  assert.match(source, /Future<bool> _cancelPendingOrder\(/);
  assert.match(source, /final paymentConfirmed = await _cancelPendingOrder\([\s\S]*?if \(paymentConfirmed\) \{\s*return;/);
});

test('startup sends an undecodable persisted token back through public auth flow', async () => {
  const source = await readFile(
    new URL('../lib/features/splash/splash_provider.dart', import.meta.url),
    'utf8',
  );
  assert.match(source, /final bool accessTokenExpired;/);
  assert.match(
    source,
    /accessTokenExpired = JwtDecoder\.isExpired\(accessToken\);[\s\S]*?await secureStorage\.clearAll\(\);[\s\S]*?context\.go\(RouteNames\.home\);/,
  );
});

test('unserviceable-location screen does not claim an area alert was registered without a callback', async () => {
  const source = await readFile(
    new URL('../lib/features/location/presentation/screens/location_unavailable_screen.dart', import.meta.url),
    'utf8',
  );
  assert.match(source, /if \(onNotify != null\)[\s\S]*?Notify Me When Available/);
  assert.match(source, /class _NotificationUnavailableNotice extends StatelessWidget/);
  assert.doesNotMatch(source, /Thanks! We(?:'|’)ll notify you when Bakaloo/);
});

test('SPA routing and fixed-upstream proxy preserve the real HTTP contract', async t => {
  const root = await mkdtemp(join(tmpdir(), 'bakaloo-server-test-'));
  await writeFile(join(root, 'index.html'), '<title>Bakaloo</title>');
  await writeFile(join(root, 'main.dart.js'), 'void 0;');
  const upstream = http.createServer((req, res) => {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      res.writeHead(422, { 'Content-Type': 'application/json', 'Cache-Control': 'public, max-age=3600' });
      res.end(JSON.stringify({ path: req.url, auth: req.headers.authorization, storefront: req.headers['x-storefront-token'], method: req.method, origin: req.headers.origin, cookie: req.headers.cookie, body }));
    });
  });
  const upstreamUrl = await listen(upstream);
  const server = createWebServer({ root, upstream: upstreamUrl });
  const base = await listen(server);
  t.after(async () => { server.closeAllConnections(); upstream.closeAllConnections(); server.close(); upstream.close(); await rm(root, { recursive: true }); });
  for (const path of ['/', '/home', '/products/fresh-fish', '/cart/checkout', '/unknown-route']) {
    const response = await fetch(base + path, { headers: { accept: 'text/html' } });
    assert.equal(response.status, 200);
    assert.match(await response.text(), /Bakaloo/);
    assert.equal(response.headers.get('cache-control'), 'no-cache');
    assert.equal(response.headers.get('permissions-policy'), 'camera=(), geolocation=(self), microphone=(self)');
  }
  assert.equal((await fetch(base + '/missing.js')).status, 404);
  assert.equal((await fetch(base + '/.env')).status, 404);
  assert.equal((await fetch(base + '/assets/missing', { headers: { accept: 'text/html' } })).status, 404);
  assert.equal((await fetch(base + '/home', { headers: { origin: 'https://untrusted.example', accept: 'text/html' } })).status, 403);
  const invalidHostStatus = await new Promise(resolve => http.get(base + '/home', { headers: { host: 'evil.example', accept: 'text/html' } }, res => { res.resume(); resolve(res.statusCode); }));
  assert.equal(invalidHostStatus, 403);
  const response = await fetch(base + '/api/v1/cart?check=1', { method: 'POST', headers: { authorization: 'Bearer test-only', 'x-storefront-token': 'test-scope', 'content-type': 'application/json', origin: base, cookie: 'not-forwarded=1' }, body: '{"quantity":2}' });
  assert.equal(response.status, 422);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.deepEqual(await response.json(), { path: '/api/v1/cart?check=1', auth: 'Bearer test-only', storefront: 'test-scope', method: 'POST', body: '{"quantity":2}' });
});

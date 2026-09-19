import http from 'node:http';
import https from 'node:https';
import { createReadStream } from 'node:fs';
import { stat, realpath } from 'node:fs/promises';
import { resolve, relative, extname, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.svg': 'image/svg+xml', '.webp': 'image/webp', '.css': 'text/css', '.ttf': 'font/ttf', '.woff2': 'font/woff2', '.ico': 'image/x-icon' };
const hopHeaders = ['connection', 'keep-alive', 'proxy-authenticate', 'proxy-authorization', 'te', 'trailer', 'transfer-encoding', 'upgrade'];
function cleanHeaders(headers) {
  const result = { ...headers };
  for (const name of [...hopHeaders, ...(headers.connection || '').split(',').map(x => x.trim().toLowerCase())]) delete result[name];
  return result;
}
function error(res, status, message) {
  if (res.headersSent) return res.destroy();
  res.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
  res.end(JSON.stringify({ success: false, message }));
}

// One fixed upstream, never a URL supplied by a request. TLS verification stays enabled.
export function createWebServer({ root = resolve('build/web'), upstream = 'https://api.fc.opslin.com', allowedHosts = ['localhost', '127.0.0.1'], publicOrigin } = {}) {
  const target = new URL(upstream);
  if (target.protocol !== 'https:' && !(target.protocol === 'http:' && ['localhost', '127.0.0.1'].includes(target.hostname))) throw new Error('Upstream must use HTTPS');
  const transport = target.protocol === 'https:' ? https : http;
  const agent = new transport.Agent({ keepAlive: true, maxSockets: 64 });
  const rootPath = resolve(root);
  const trusted = req => {
    try {
      const host = new URL(`http://${req.headers.host}`);
      if (!allowedHosts.includes(host.hostname)) return false;
      return !req.headers.origin || req.headers.origin === publicOrigin || req.headers.origin === `http://${req.headers.host}`;
    } catch { return false; }
  };
  const proxyHeaders = req => {
    const headers = cleanHeaders(req.headers);
    for (const key of Object.keys(headers)) {
      if (key.startsWith('x-forwarded-') || key.startsWith('sec-fetch-') || ['forwarded', 'origin', 'referer', 'cookie'].includes(key)) delete headers[key];
    }
    headers.host = target.host;
    return headers;
  };
  const server = http.createServer(async (req, res) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
    res.setHeader('X-Frame-Options', 'DENY');
    // Browser capabilities are opt-in and same-origin only. Bakaloo needs
    // geolocation and microphone for its location/voice-search flows, while
    // it has no camera feature in the Web experience.
    res.setHeader(
      'Permissions-Policy',
      'camera=(), geolocation=(self), microphone=(self)',
    );
    if (!trusted(req)) return error(res, 403, 'Origin or host is not allowed.');
    if (!req.url?.startsWith('/') || req.url.startsWith('//') || /[\\\u0000]/.test(req.url)) return error(res, 400, 'Invalid path.');
    let pathname;
    try { pathname = decodeURIComponent(req.url.split('?')[0]); } catch { return error(res, 400, 'Invalid path.'); }
    if (pathname.split('/').some(part => part === '..' || part.startsWith('.')) || pathname.includes('\\')) return error(res, 404, 'Not found.');
    const isApi = pathname === '/api/v1' || pathname.startsWith('/api/v1/');
    const isSocket = pathname.startsWith('/socket.io/');
    // Keep one browser-storage origin for the preview. A stale IndexedDB cache
    // under 127.0.0.1 can otherwise prevent a new Flutter tab from starting,
    // even though localhost itself is healthy. API and socket requests stay
    // on their requested host so the proxy remains transparent.
    const requestHost = new URL(`http://${req.headers.host}`).hostname;
    if (!isApi && !isSocket && requestHost === '127.0.0.1' && ['GET', 'HEAD'].includes(req.method)) {
      const port = new URL(`http://${req.headers.host}`).port;
      res.writeHead(308, { Location: `http://localhost${port ? `:${port}` : ''}${req.url}`, 'Cache-Control': 'no-store' });
      return res.end();
    }
    if (isApi || isSocket) {
      if (!['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'].includes(req.method)) return error(res, 405, 'Method not allowed.');
      if (Number(req.headers['content-length'] || 0) > 20 * 1024 * 1024) return error(res, 413, 'Request too large.');
      const request = transport.request({ hostname: target.hostname, port: target.port, method: req.method, path: req.url, headers: proxyHeaders(req), agent }, response => {
        const headers = cleanHeaders(response.headers);
        delete headers['set-cookie'];
        for (const key of Object.keys(headers)) if (key.startsWith('access-control-')) delete headers[key];
        res.writeHead(response.statusCode, { ...headers, 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
        response.pipe(res);
      });
      request.setTimeout(30000, () => request.destroy(new Error('timeout')));
      request.on('error', () => error(res, 502, 'The service is temporarily unavailable. Please retry.'));
      let received = 0;
      req.on('data', chunk => { received += chunk.length; if (received > 20 * 1024 * 1024) { error(res, 413, 'Request too large.'); request.destroy(); } });
      req.on('aborted', () => request.destroy());
      res.on('close', () => request.destroy());
      req.pipe(request);
      return;
    }
    if (!['GET', 'HEAD'].includes(req.method)) return error(res, 405, 'Method not allowed.');
    let file = resolve(rootPath, '.' + pathname);
    const inside = path => { const rel = relative(rootPath, path); return rel !== '..' && !rel.startsWith('..' + sep) && !rel.includes(':'); };
    if (!inside(file)) return error(res, 404, 'Not found.');
    try {
      let info = await stat(file).catch(() => null);
      if (!info?.isFile()) {
        // Missing assets must remain 404; only document navigations get the SPA shell.
        if (pathname.startsWith('/assets/') || pathname.startsWith('/icons/') || pathname.startsWith('/canvaskit/') || extname(pathname)) return error(res, 404, 'Not found.');
        file = resolve(rootPath, 'index.html');
        info = await stat(file);
      }
      if (!inside(await realpath(file))) return error(res, 404, 'Not found.');
      res.writeHead(200, { 'Content-Type': types[extname(file)] || 'application/octet-stream', 'Content-Length': info.size, 'Cache-Control': ['.html', '.js', '.json'].includes(extname(file)) ? 'no-cache' : 'public, max-age=3600' });
      if (req.method === 'HEAD') return res.end();
      createReadStream(file).on('error', () => res.destroy()).pipe(res);
    } catch { error(res, 503, 'Web build unavailable. Run flutter build web first.'); }
  });
  server.on('upgrade', (req, socket, head) => {
    if (!trusted(req) || !/^\/socket\.io\/\?/.test(req.url) || req.headers.upgrade?.toLowerCase() !== 'websocket') return socket.destroy();
    const headers = { ...proxyHeaders(req), connection: 'Upgrade', upgrade: 'websocket' };
    const request = transport.request({ hostname: target.hostname, port: target.port, path: req.url, headers });
    request.setTimeout(15000, () => request.destroy());
    request.on('upgrade', (response, upstreamSocket, upstreamHead) => {
      socket.write(`HTTP/1.1 101 Switching Protocols\r\n${Object.entries(response.headers).map(([key, value]) => `${key}: ${value}`).join('\r\n')}\r\n\r\n`);
      if (head.length) upstreamSocket.write(head);
      if (upstreamHead.length) socket.write(upstreamHead);
      socket.pipe(upstreamSocket).pipe(socket);
      socket.on('close', () => upstreamSocket.destroy());
      upstreamSocket.on('error', () => socket.destroy());
      upstreamSocket.on('close', () => socket.destroy());
    });
    request.on('response', () => socket.destroy());
    request.on('error', () => socket.destroy());
    socket.on('error', () => request.destroy());
    request.end();
  });
  server.headersTimeout = 15000;
  server.requestTimeout = 60000;
  server.on('close', () => agent.destroy());
  return server;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const port = Number(process.env.PORT || 8080);
  const server = createWebServer({ publicOrigin: process.env.PUBLIC_ORIGIN, allowedHosts: (process.env.ALLOWED_HOSTS || 'localhost,127.0.0.1').split(',') });
  server.listen(port, process.env.HOST || '127.0.0.1', () => console.log(`Bakaloo preview: http://127.0.0.1:${port}/home`));
  for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => { server.close(); server.closeAllConnections(); });
}

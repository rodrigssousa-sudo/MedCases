/**
 * MedCases Pro — PWA Service Worker v10.0.0
 * Build 116: bloco único contínuo, smart scroll, supressão de rótulos de modo, flutter_markdown.
 * Estratégia: network-first para main.dart.js e index.html (sempre frescos)
 *             cache-first para assets estáticos, ícones e fontes.
 */

'use strict';

const SW_VERSION   = '40.0.0';
const CACHE_APP    = 'medcases-app-v40.0.0';  // ← Build 146: anti-buffering SSE (fetch nativo Web, TCP_NODELAY, socket.write direto)
const CACHE_FONTS  = 'medcases-fonts-v2';

// Assets pré-cacheados no install (críticos para o boot)
const PRECACHE = [
  './',
  './flutter_bootstrap.js',
  './flutter.js',
  './manifest.json',
  './icons/Icon-192.png',
  './icons/Icon-512.png',
  './icons/Icon-maskable-192.png',
  './icons/Icon-maskable-512.png',
];

// Nunca cachear APIs, Firebase, Google Auth
const NEVER_CACHE = [
  /firestore\.googleapis\.com/,
  /firebase\.googleapis\.com/,
  /identitytoolkit\.googleapis\.com/,
  /securetoken\.googleapis\.com/,
  /accounts\.google\.com/,
  /gsi\/client/,
  /googleapis\.com\/oauth2/,
  /chrome-extension/,
  /\/api\//,
];

const FONT_URLS = [/fonts\.googleapis\.com/, /fonts\.gstatic\.com/];

function neverCache(url) { return NEVER_CACHE.some(p => p.test(url)); }
function isFont(url)     { return FONT_URLS.some(p => p.test(url)); }

// CRÍTICO: usa string .includes() não url.pathname (que seria undefined numa string)
function isMainDartJs(url) {
  return url.includes('main.dart.js');
}
function isBigAsset(url) {
  return url.includes('flutter_bootstrap.js') || url.includes('flutter.js');
}
function isStaticAsset(url) {
  return /\.(js|css|png|jpg|jpeg|svg|ico|woff|woff2|ttf|json|wasm)(\?.*)?$/.test(url);
}

// ── INSTALL ────────────────────────────────────────────────────────────────────
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_APP)
      .then(cache => Promise.allSettled(PRECACHE.map(u => cache.add(u).catch(() => {}))))
      .then(() => self.skipWaiting())   // ativa imediatamente
  );
});

// ── ACTIVATE ───────────────────────────────────────────────────────────────────
// Apaga TODOS os caches antigos — versão nova = tudo do zero
self.addEventListener('activate', event => {
  const keep = [CACHE_APP, CACHE_FONTS];
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(
        keys.filter(k => !keep.includes(k)).map(k => {
          console.log('[SW v10] deletando cache antigo:', k);
          return caches.delete(k);
        })
      ))
      .then(() => self.clients.claim())
  );
});

// ── FETCH ──────────────────────────────────────────────────────────────────────
self.addEventListener('fetch', event => {
  const { request } = event;
  const url = request.url;   // string — NÃO é um objeto URL

  if (request.method !== 'GET') return;
  if (neverCache(url)) return;
  if (url.startsWith('chrome-extension://')) return;
  if (url.includes('nocache=') || url.includes('bust=')) return;

  // ── Fontes: cache permanente ───────────────────────────────────────────────
  if (isFont(url)) {
    event.respondWith(
      caches.open(CACHE_FONTS).then(cache =>
        cache.match(request).then(hit => hit || fetch(request).then(res => {
          if (res.ok) cache.put(request, res.clone());
          return res;
        }))
      )
    );
    return;
  }

  // ── index.html: network-first (sempre fresco) ──────────────────────────────
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
        .then(res => {
          if (res.ok) {
            caches.open(CACHE_APP).then(c => c.put(request, res.clone()));
          }
          return res;
        })
        .catch(() =>
          caches.open(CACHE_APP)
            .then(c => c.match('./') || c.match('./index.html'))
            .then(cached => cached || new Response(
              `<!DOCTYPE html><html><head><meta charset="UTF-8">
               <title>MedCases Pro — Offline</title>
               <style>body{background:#07110d;color:#fff;font-family:sans-serif;
               display:flex;flex-direction:column;align-items:center;justify-content:center;
               height:100vh;margin:0;text-align:center}h2{color:#C5A365}
               p{color:rgba(255,255,255,.5);max-width:280px}
               button{margin-top:24px;padding:12px 28px;border-radius:12px;
               background:#1F6B48;color:#fff;border:none;font-size:15px;cursor:pointer}
               </style></head><body>
               <h2>Sem conexão</h2>
               <p>Conecte-se à internet para usar o MedCases Pro.</p>
               <button onclick="location.reload()">Tentar novamente</button>
               </body></html>`,
              { headers: { 'Content-Type': 'text/html; charset=utf-8' } }
            ))
        )
    );
    return;
  }

  // ── main.dart.js: SEMPRE network-first com cache: no-store ─────────────────
  // CRÍTICO: isMainDartJs usa string.includes(), não url.pathname (seria undefined)
  if (isMainDartJs(url)) {
    event.respondWith(
      fetch(request, { cache: 'no-store' })
        .then(res => {
          if (res && res.ok) {
            const clone = res.clone();
            caches.open(CACHE_APP).then(cache => cache.put(request, clone));
          }
          return res;
        })
        .catch(async () => {
          const cache = await caches.open(CACHE_APP);
          return cache.match(request);
        })
    );
    return;
  }

  // ── flutter_bootstrap.js e flutter.js: network-first (têm ?v= hash) ────────
  if (isBigAsset(url)) {
    event.respondWith(
      fetch(request, { cache: 'no-store' })
        .then(res => {
          if (res && res.ok) {
            caches.open(CACHE_APP).then(cache => cache.put(request, res.clone()));
          }
          return res;
        })
        .catch(async () => {
          const cache = await caches.open(CACHE_APP);
          return cache.match(request);
        })
    );
    return;
  }

  // ── Assets estáticos: cache-first ─────────────────────────────────────────
  if (isStaticAsset(url)) {
    event.respondWith(
      caches.open(CACHE_APP).then(cache =>
        cache.match(request).then(hit => hit || fetch(request).then(res => {
          if (res.ok) cache.put(request, res.clone());
          return res;
        }).catch(() => null))
      )
    );
    return;
  }
});

// ── MESSAGE ────────────────────────────────────────────────────────────────────
self.addEventListener('message', event => {
  if (!event.data) return;
  if (event.data.type === 'GET_VERSION') {
    if (event.ports[0]) event.ports[0].postMessage({ version: SW_VERSION });
  }
  if (event.data.type === 'CLEAR_CACHE') {
    caches.keys()
      .then(keys => Promise.all(keys.map(k => caches.delete(k))))
      .then(() => { if (event.ports[0]) event.ports[0].postMessage({ ok: true }); });
  }
  if (event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

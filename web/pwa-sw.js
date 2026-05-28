/**
 * MedCases Pro — PWA Service Worker v6.2.1
 * Estratégia: network-first para main.dart.js e index.html (sempre frescos)
 *             cache-first para assets estáticos, ícones e fontes.
 * Resultado: bundles antigos deixam de ser servidos de imediato após deploy.
 */

'use strict';

const SW_VERSION   = '6.2.2';
const CACHE_APP    = 'medcases-app-v6.2.2';
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

// Assets grandes continuam cacheados, exceto main.dart.js
const BIG_ASSETS = /\/(flutter_bootstrap\.js|flutter\.js)(\?.*)?$/;

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
function isBigAsset(url) { return BIG_ASSETS.test(url); }
function isStaticAsset(url) {
  return /\.(js|css|png|jpg|jpeg|svg|ico|woff|woff2|ttf|json|wasm)(\?.*)?$/.test(url);
}

// ── INSTALL ────────────────────────────────────────────────────────────────────
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_APP)
      .then(cache => Promise.allSettled(PRECACHE.map(u => cache.add(u).catch(() => {}))))
      .then(() => self.skipWaiting())   // ativa imediatamente — sem toast necessário
  );
});

// ── ACTIVATE ───────────────────────────────────────────────────────────────────
// Remove caches de versões anteriores, mantém só os atuais
self.addEventListener('activate', event => {
  const keep = [CACHE_APP, CACHE_FONTS];
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(
        keys.filter(k => !keep.includes(k)).map(k => caches.delete(k))
      ))
      .then(() => self.clients.claim())
  );
});

// ── FETCH ──────────────────────────────────────────────────────────────────────
self.addEventListener('fetch', event => {
  const { request } = event;
  const url = request.url;

  if (request.method !== 'GET') return;
  if (neverCache(url)) return;
  if (url.startsWith('chrome-extension://')) return;
  // URLs com nocache= ou bust= → sempre rede (cache bust manual)
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

  // ── main.dart.js: network-first + fallback ao cache offline ───────────────
  if (url.pathname.endsWith('/main.dart.js')) {
    event.respondWith(
      fetch(request, { cache: 'no-store' })
        .then(res => {
          if (res && res.ok) {
            const clone = res.clone();
            caches.open(CACHE_APP).then(cache => {
              cache.put(request, clone);
            });
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

  // ── flutter_bootstrap.js e flutter.js: stale-while-revalidate ─────────────
  if (isBigAsset(url)) {
    event.respondWith(
      caches.open(CACHE_APP).then(async cache => {
        const cached = await cache.match(request);
        const fetchPromise = fetch(request).then(res => {
          if (res.ok) cache.put(request, res.clone());
          return res;
        }).catch(() => null);
        return cached || fetchPromise;
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
});

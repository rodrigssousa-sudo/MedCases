/**
 * MedCases Pro — PWA Service Worker v4.1.0
 *
 * CORREÇÃO v4.1.0:
 * - REMOVIDO skipWaiting() do install — era a causa do loop de reload
 * - skipWaiting() só ocorre via postMessage({ type: 'SKIP_WAITING' })
 * - Primeiro registro nunca dispara controllerchange desnecessário
 */

'use strict';

const SW_VERSION   = '4.1.0';
const CACHE_STATIC = 'medcases-static-v4.1.0';
const CACHE_FONTS  = 'medcases-fonts-v1'; // fontes mudam raramente, versão fixa

// Assets essenciais pré-cacheados no install
const PRECACHE_ASSETS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/favicon.png',
  '/flutter_bootstrap.js',
  '/main.dart.js',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/icons/Icon-maskable-192.png',
  '/icons/Icon-maskable-512.png',
];

// Nunca cachear: Firebase, Auth, APIs dinâmicas
const NEVER_CACHE = [
  /firestore\.googleapis\.com/,
  /firebase\.googleapis\.com/,
  /identitytoolkit\.googleapis\.com/,
  /securetoken\.googleapis\.com/,
  /firebasestorage\.googleapis\.com/,
  /accounts\.google\.com/,
  /gsi\/client/,
  /\/api\//,
  /chrome-extension/,
];

const FONT_PATTERNS = [
  /fonts\.googleapis\.com/,
  /fonts\.gstatic\.com/,
];

function shouldNeverCache(url) {
  return NEVER_CACHE.some(p => p.test(url));
}
function isFont(url) {
  return FONT_PATTERNS.some(p => p.test(url));
}
function isStaticAsset(url) {
  return /\.(js|css|png|jpg|jpeg|svg|ico|woff|woff2|ttf|json)(\?.*)?$/.test(url);
}

// ── INSTALL ───────────────────────────────────────────────────────────────────
// NÃO chama skipWaiting() aqui.
// O SW fica em "waiting" até o usuário confirmar o update via toast.
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_STATIC).then(cache =>
      Promise.allSettled(
        PRECACHE_ASSETS.map(url => cache.add(url).catch(() => {}))
      )
    )
    // SEM self.skipWaiting() — evita o loop de reload
  );
});

// ── ACTIVATE ─────────────────────────────────────────────────────────────────
// Limpa caches de versões anteriores e toma controle das abas.
self.addEventListener('activate', event => {
  const keep = [CACHE_STATIC, CACHE_FONTS];
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(
        keys.filter(k => !keep.includes(k)).map(k => caches.delete(k))
      ))
      .then(() => self.clients.claim())
  );
});

// ── FETCH ─────────────────────────────────────────────────────────────────────
self.addEventListener('fetch', event => {
  const { request } = event;
  const url = request.url;

  if (request.method !== 'GET') return;
  if (shouldNeverCache(url)) return;
  if (url.startsWith('chrome-extension://')) return;

  // Fontes: cache-first longo
  if (isFont(url)) {
    event.respondWith(
      caches.open(CACHE_FONTS).then(cache =>
        cache.match(request).then(hit => {
          if (hit) return hit;
          return fetch(request).then(res => {
            if (res.ok) cache.put(request, res.clone());
            return res;
          });
        })
      )
    );
    return;
  }

  // Assets estáticos: cache-first
  if (isStaticAsset(url)) {
    event.respondWith(
      caches.open(CACHE_STATIC).then(cache =>
        cache.match(request).then(hit => {
          if (hit) return hit;
          return fetch(request).then(res => {
            if (res.ok) cache.put(request, res.clone());
            return res;
          }).catch(() => cache.match('/index.html'));
        })
      )
    );
    return;
  }

  // Navegação HTML: network-first com fallback offline
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
        .then(res => {
          if (res.ok) {
            caches.open(CACHE_STATIC).then(c => c.put(request, res.clone()));
          }
          return res;
        })
        .catch(() =>
          caches.open(CACHE_STATIC)
            .then(c => c.match('/index.html'))
            .then(cached => cached || new Response(
              `<!DOCTYPE html><html lang="pt-BR"><head>
              <meta charset="UTF-8">
              <meta name="viewport" content="width=device-width,initial-scale=1">
              <title>MedCases Pro — Offline</title>
              <style>
                body{background:#07110d;color:#fff;font-family:-apple-system,sans-serif;
                  display:flex;flex-direction:column;align-items:center;justify-content:center;
                  height:100vh;margin:0;text-align:center;padding:24px}
                .logo{width:72px;height:72px;border-radius:18px;
                  background:linear-gradient(135deg,#075f45,#07110d);
                  display:flex;align-items:center;justify-content:center;
                  margin-bottom:24px;box-shadow:0 8px 32px rgba(0,0,0,.4)}
                .logo span{color:#FFE8A6;font-size:32px;font-weight:900}
                h2{color:#C5A365;margin:0 0 8px}
                p{color:rgba(255,255,255,.5);font-size:14px;max-width:280px;line-height:1.6}
                button{margin-top:24px;padding:12px 28px;border-radius:12px;
                  background:#1F6B48;color:#fff;border:none;font-size:15px;
                  font-weight:600;cursor:pointer}
              </style></head><body>
              <div class="logo"><span>M</span></div>
              <h2>Sem conexão</h2>
              <p>O MedCases Pro precisa de internet para carregar dados clínicos atualizados.</p>
              <button onclick="location.reload()">Tentar novamente</button>
              </body></html>`,
              { headers: { 'Content-Type': 'text/html; charset=utf-8' } }
            ))
        )
    );
    return;
  }

  // Demais: pass-through sem cache
});

// ── MESSAGE ───────────────────────────────────────────────────────────────────
self.addEventListener('message', event => {
  if (!event.data) return;
  switch (event.data.type) {
    case 'SKIP_WAITING':
      // Só ativa quando o usuário confirma o update no toast
      self.skipWaiting();
      break;
    case 'GET_VERSION':
      if (event.ports[0]) event.ports[0].postMessage({ version: SW_VERSION });
      break;
    case 'CLEAR_CACHE':
      caches.keys()
        .then(keys => Promise.all(keys.map(k => caches.delete(k))))
        .then(() => { if (event.ports[0]) event.ports[0].postMessage({ ok: true }); });
      break;
  }
});

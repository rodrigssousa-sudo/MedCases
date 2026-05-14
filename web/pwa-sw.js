/**
 * MedCases Pro — PWA Service Worker v4.0.0
 * Estratégia: Cache-first para assets estáticos, Network-first para dados.
 * Auto-update: detecta nova versão, limpa cache antigo, aplica sem reinstalar.
 */

'use strict';

// ─── Versão do cache — alterar a cada deploy para forçar atualização ──────────
const SW_VERSION   = '4.0.0';
const CACHE_STATIC = 'medcases-static-v4.0.0';
const CACHE_FONTS  = 'medcases-fonts-v4.0.0';

// ─── Assets essenciais a pré-cachear no install ───────────────────────────────
const PRECACHE_ASSETS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/favicon.png',
  '/flutter_bootstrap.js',
  '/main.dart.js',
  '/flutter.js',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/icons/Icon-maskable-192.png',
  '/icons/Icon-maskable-512.png',
];

// ─── Padrões que NUNCA devem ser cacheados ────────────────────────────────────
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

// ─── Padrões de fontes do Google (cache longo) ────────────────────────────────
const FONT_PATTERNS = [
  /fonts\.googleapis\.com/,
  /fonts\.gstatic\.com/,
];

// ─── Helper: verificar se URL deve ser ignorada ───────────────────────────────
function shouldNeverCache(url) {
  return NEVER_CACHE.some(pattern => pattern.test(url));
}

function isFont(url) {
  return FONT_PATTERNS.some(pattern => pattern.test(url));
}

function isStaticAsset(url) {
  return /\.(js|css|png|jpg|jpeg|svg|ico|woff|woff2|ttf|json)(\?.*)?$/.test(url);
}

// ─── INSTALL: pré-cachear assets essenciais ───────────────────────────────────
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_STATIC)
      .then(cache => {
        // Cacheia em paralelo, falhas individuais não bloqueiam
        return Promise.allSettled(
          PRECACHE_ASSETS.map(url =>
            cache.add(url).catch(() => { /* ignora falha individual */ })
          )
        );
      })
      .then(() => self.skipWaiting()) // Ativa imediatamente sem esperar aba fechar
  );
});

// ─── ACTIVATE: limpar caches de versões anteriores ───────────────────────────
self.addEventListener('activate', event => {
  const validCaches = [CACHE_STATIC, CACHE_FONTS];

  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(
        keys
          .filter(key => !validCaches.includes(key))
          .map(key => {
            console.log('[SW] Removendo cache antigo:', key);
            return caches.delete(key);
          })
      ))
      .then(() => self.clients.claim()) // Toma controle de todas as abas abertas
  );
});

// ─── FETCH: estratégia por tipo de recurso ────────────────────────────────────
self.addEventListener('fetch', event => {
  const { request } = event;
  const url = request.url;

  // Ignorar requisições não-GET
  if (request.method !== 'GET') return;

  // Ignorar URLs que não devem ser cacheadas (Firebase, APIs, etc.)
  if (shouldNeverCache(url)) return;

  // Ignorar extensões de navegador
  if (url.startsWith('chrome-extension://')) return;

  // Fontes: Cache-first com fallback de rede (TTL longo)
  if (isFont(url)) {
    event.respondWith(
      caches.open(CACHE_FONTS).then(cache =>
        cache.match(request).then(cached => {
          if (cached) return cached;
          return fetch(request).then(response => {
            if (response.ok) cache.put(request, response.clone());
            return response;
          });
        })
      )
    );
    return;
  }

  // Assets estáticos (.js, .css, .png, etc.): Cache-first
  if (isStaticAsset(url)) {
    event.respondWith(
      caches.open(CACHE_STATIC).then(cache =>
        cache.match(request).then(cached => {
          if (cached) return cached;
          return fetch(request).then(response => {
            if (response.ok) cache.put(request, response.clone());
            return response;
          }).catch(() => {
            // Offline fallback: retorna index.html para navegação
            return cache.match('/index.html');
          });
        })
      )
    );
    return;
  }

  // Navegação (HTML pages): Network-first com fallback para cache
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
        .then(response => {
          // Cacheia a nova versão do index.html
          if (response.ok) {
            const clone = response.clone();
            caches.open(CACHE_STATIC).then(c => c.put(request, clone));
          }
          return response;
        })
        .catch(() => {
          // Offline: retorna index.html do cache
          return caches.open(CACHE_STATIC)
            .then(cache => cache.match('/index.html'))
            .then(cached => cached || new Response(
              `<!DOCTYPE html>
              <html lang="pt-BR">
              <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>MedCases Pro — Offline</title>
                <style>
                  body { background:#07110d; color:#fff; font-family:-apple-system,sans-serif;
                         display:flex; flex-direction:column; align-items:center;
                         justify-content:center; height:100vh; margin:0; text-align:center; }
                  .logo { width:72px; height:72px; border-radius:18px;
                          background:linear-gradient(135deg,#075f45,#07110d);
                          display:flex; align-items:center; justify-content:center;
                          margin-bottom:24px; box-shadow:0 8px 32px rgba(0,0,0,.4); }
                  .logo span { color:#FFE8A6; font-size:32px; font-weight:900; }
                  h2 { color:#C5A365; margin:0 0 8px; }
                  p  { color:rgba(255,255,255,.5); font-size:14px; max-width:280px; line-height:1.6; }
                  button { margin-top:24px; padding:12px 28px; border-radius:12px;
                           background:#1F6B48; color:#fff; border:none;
                           font-size:15px; font-weight:600; cursor:pointer; }
                </style>
              </head>
              <body>
                <div class="logo"><span>M</span></div>
                <h2>Sem conexão</h2>
                <p>O MedCases Pro requer internet para carregar dados clínicos atualizados.</p>
                <button onclick="location.reload()">Tentar novamente</button>
              </body>
              </html>`,
              { headers: { 'Content-Type': 'text/html; charset=utf-8' } }
            ));
        })
    );
    return;
  }

  // Demais requests: pass-through (sem cache)
});

// ─── MESSAGE: comandos do app principal ───────────────────────────────────────
self.addEventListener('message', event => {
  if (!event.data) return;

  switch (event.data.type) {
    // App pede para SW aplicar update agora
    case 'SKIP_WAITING':
      self.skipWaiting();
      break;

    // App pede versão atual do SW
    case 'GET_VERSION':
      event.ports[0]?.postMessage({ version: SW_VERSION });
      break;

    // App pede limpeza de cache (após update forçado)
    case 'CLEAR_CACHE':
      caches.keys()
        .then(keys => Promise.all(keys.map(k => caches.delete(k))))
        .then(() => event.ports[0]?.postMessage({ ok: true }));
      break;
  }
});

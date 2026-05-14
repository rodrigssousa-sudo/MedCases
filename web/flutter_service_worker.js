'use strict';

// MedCases Pro — Service Worker com Cache-First agressivo
// Estratégia:
//   - main.dart.js, flutter.js, assets → cache-first (imutáveis entre versões)
//   - index.html, manifest.json        → network-first (podem mudar)
//   - Firebase/Google CDN              → network-only (externos, não cacheamos)

var CACHE_VERSION = 'medcases-v3.0.0';

var CACHE_FIRST_PATTERNS = [
  /main\.dart\.js$/,
  /flutter\.js$/,
  /flutter_bootstrap\.js$/,
  /canvaskit\//,
  /assets\//,
  /icons\//,
  /favicon\.png$/,
];

var NETWORK_ONLY_PATTERNS = [
  /firebasejs/,
  /googleapis\.com/,
  /gstatic\.com/,
  /accounts\.google\.com/,
];

self.addEventListener('install', function (e) {
  self.skipWaiting();
  e.waitUntil(
    caches.open(CACHE_VERSION).then(function (cache) {
      // Pré-cacheia os recursos críticos de boot
      return cache.addAll([
        './',
        'main.dart.js',
        'flutter_bootstrap.js',
        'flutter.js',
        'manifest.json',
        'favicon.png',
      ]).catch(function () {
        // Ignora erros de pré-cache (offline no install)
      });
    })
  );
});

self.addEventListener('activate', function (e) {
  e.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(
        keys
          .filter(function (k) { return k !== CACHE_VERSION; })
          .map(function (k) { return caches.delete(k); })
      );
    }).then(function () {
      return self.clients.claim();
    })
  );
});

self.addEventListener('fetch', function (e) {
  var url = e.request.url;

  // Ignora não-GET e requests de outros domínios externos (Firebase, Google)
  if (e.request.method !== 'GET') return;
  if (NETWORK_ONLY_PATTERNS.some(function (p) { return p.test(url); })) return;

  // Cache-first para assets estáticos imutáveis
  if (CACHE_FIRST_PATTERNS.some(function (p) { return p.test(url); })) {
    e.respondWith(
      caches.match(e.request).then(function (cached) {
        if (cached) return cached;
        return fetch(e.request).then(function (response) {
          if (response && response.status === 200) {
            var clone = response.clone();
            caches.open(CACHE_VERSION).then(function (cache) {
              cache.put(e.request, clone);
            });
          }
          return response;
        });
      })
    );
    return;
  }

  // Network-first para index.html e outros (garante conteúdo atualizado)
  e.respondWith(
    fetch(e.request)
      .then(function (response) {
        if (response && response.status === 200) {
          var clone = response.clone();
          caches.open(CACHE_VERSION).then(function (cache) {
            cache.put(e.request, clone);
          });
        }
        return response;
      })
      .catch(function () {
        return caches.match(e.request);
      })
  );
});

'use strict';
// MedCases Pro — SW Destruidor v3.2.0
// Resolve imediatamente no install para não bloquear o Flutter bootstrap (4000ms limit).
// Apaga caches e se auto-remove no activate, sem segurar o prepareServiceWorker.
self.addEventListener('install', function(e) {
  // skipWaiting() + resolve imediato — flutter_bootstrap.js não espera mais
  self.skipWaiting();
});
self.addEventListener('activate', function(e) {
  e.waitUntil(
    caches.keys().then(function(keys) {
      return Promise.all(keys.map(function(k) { return caches.delete(k); }));
    }).then(function() {
      return self.registration.unregister();
    })
    // Sem navigate() — evita reload em loop após unregister
  );
});
self.addEventListener('fetch', function(e) {
  // Pass-through: nunca cacheia, sempre vai à rede
  e.respondWith(fetch(e.request));
});

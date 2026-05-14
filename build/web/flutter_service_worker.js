'use strict';
// MedCases Pro — SW Destruidor v3.1.2
// Apaga TODOS os caches do browser e se auto-remove.
// Garante que o usuário sempre recebe o build mais recente.
self.addEventListener('install', function(e) {
  self.skipWaiting();
});
self.addEventListener('activate', function(e) {
  e.waitUntil(
    caches.keys().then(function(keys) {
      return Promise.all(keys.map(function(k) { return caches.delete(k); }));
    }).then(function() {
      return self.registration.unregister();
    }).then(function() {
      return self.clients.matchAll({ type: 'window' });
    }).then(function(cs) {
      cs.forEach(function(c) { c.navigate(c.url); });
    })
  );
});
self.addEventListener('fetch', function(e) {
  e.respondWith(fetch(e.request));
});

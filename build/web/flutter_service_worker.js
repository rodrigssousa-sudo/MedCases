// MedCases Pro — SW Destruidor
// Apaga todos os caches do browser e se auto-remove.
'use strict';
self.addEventListener('install', function(e) { self.skipWaiting(); });
self.addEventListener('activate', function(e) {
  e.waitUntil(
    caches.keys().then(function(keys) {
      return Promise.all(keys.map(function(k) { return caches.delete(k); }));
    }).then(function() { return self.registration.unregister(); })
    .then(function() { return self.clients.matchAll({ type: 'window' }); })
    .then(function(cs) { cs.forEach(function(c) { c.navigate(c.url); }); })
  );
});
self.addEventListener('fetch', function(e) { e.respondWith(fetch(e.request)); });

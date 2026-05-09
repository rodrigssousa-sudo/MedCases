// MedCases Pro — SW Destruidor
// Substitui o flutter_service_worker.js gerado automaticamente.
// Ao ser instalado pelo browser, apaga todos os caches e se remove.
// Isso quebra o ciclo vicioso de SW antigo servindo arquivos em cache.

'use strict';

self.addEventListener('install', function(event) {
  // Ativa imediatamente sem esperar abas fecharem
  self.skipWaiting();
});

self.addEventListener('activate', function(event) {
  event.waitUntil(
    caches.keys()
      .then(function(keys) {
        return Promise.all(keys.map(function(key) {
          return caches.delete(key);
        }));
      })
      .then(function() {
        // Remove este próprio SW após limpar tudo
        return self.registration.unregister();
      })
      .then(function() {
        // Força reload em todas as abas para carregar o app fresh
        return self.clients.matchAll({ type: 'window' });
      })
      .then(function(clients) {
        clients.forEach(function(client) {
          client.navigate(client.url);
        });
      })
  );
});

// Passa todas as requisições direto para a rede — sem cache
self.addEventListener('fetch', function(event) {
  event.respondWith(fetch(event.request));
});

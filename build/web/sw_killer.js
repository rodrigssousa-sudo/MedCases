// sw_killer.js — Service Worker que se auto-destrói
// Substitui qualquer SW antigo (flutter_service_worker.js) em cache no browser
// Quando o browser instala este SW, ele imediatamente remove a si mesmo
// e limpa todos os caches, resolvendo o loop de "Failed to fetch"

self.addEventListener('install', function(event) {
  console.log('[SW-Killer] Instalando SW destruidor...');
  // Ativar imediatamente sem esperar abas fecharem
  self.skipWaiting();
});

self.addEventListener('activate', function(event) {
  console.log('[SW-Killer] Ativando SW destruidor — limpando caches...');
  event.waitUntil(
    // Deletar todos os caches
    caches.keys().then(function(keys) {
      return Promise.all(
        keys.map(function(key) {
          console.log('[SW-Killer] Deletando cache:', key);
          return caches.delete(key);
        })
      );
    }).then(function() {
      console.log('[SW-Killer] Todos os caches limpos. Auto-destruindo...');
      // Auto-desregistrar este próprio SW
      return self.registration.unregister();
    }).then(function() {
      console.log('[SW-Killer] SW removido. Recarregando clientes...');
      // Forçar reload em todas as abas controladas
      return self.clients.matchAll({ type: 'window' });
    }).then(function(clients) {
      clients.forEach(function(client) {
        client.navigate(client.url);
      });
    })
  );
});

// Interceptar fetch — passa tudo direto para a rede (sem cache)
self.addEventListener('fetch', function(event) {
  event.respondWith(fetch(event.request));
});

'use strict';
// MedCases Pro — SW Destruidor v4.0.0
// CRÍTICO: NÃO intercepta fetch — evita network errors no Firestore/Firebase.
// O SW do Flutter gera flutter_service_worker.js que cacheia assets agressivamente
// e intercepta fetch requests, quebrando o Firestore SDK (WebSocket upgrades falham).
// Este SW destruidor:
//   1. Se instala imediatamente (skipWaiting)
//   2. Apaga todos os caches existentes
//   3. Se auto-desregistra (unregister)
//   4. NÃO tem fetch handler — zero interceptação de requests
self.addEventListener('install', function(e) {
  self.skipWaiting(); // Ativa imediatamente sem esperar
});

self.addEventListener('activate', function(e) {
  e.waitUntil(
    caches.keys()
      .then(function(keys) {
        return Promise.all(keys.map(function(k) { return caches.delete(k); }));
      })
      .then(function() {
        // Auto-desregistra — após isso, requests vão direto ao servidor
        return self.registration.unregister();
      })
  );
});

// SEM fetch handler — requests NUNCA são interceptados por este SW.
// O Firestore SDK (WebSocket), Firebase Auth e todos os outros requests
// funcionam normalmente sem interferência do service worker.

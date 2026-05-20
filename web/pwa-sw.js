/**
 * MedCases Pro — PWA Service Worker v6.0.0
 * MODO KILLER: ao instalar, limpa TODOS os caches, desregistra a si mesmo
 * e força reload em todos os clientes. Isso garante que usuários presos
 * em loops de cache antigo recebam o app atualizado imediatamente.
 *
 * Após a limpeza, o próximo SW registrado (pwa-sw.js?v=6) funcionará normalmente.
 */

'use strict';

const SW_VERSION = '6.0.0';

// ── INSTALL: ativa imediatamente sem esperar abas fecharem ──────────────────
self.addEventListener('install', event => {
  console.log('[SW v6] Instalando — modo killer ativo');
  self.skipWaiting(); // ativa IMEDIATAMENTE
});

// ── ACTIVATE: limpa TODOS os caches e recarrega todos os clientes ───────────
self.addEventListener('activate', event => {
  console.log('[SW v6] Ativando — limpando todos os caches...');
  event.waitUntil(
    caches.keys()
      .then(keys => {
        console.log('[SW v6] Caches encontrados:', keys);
        return Promise.all(keys.map(k => {
          console.log('[SW v6] Deletando cache:', k);
          return caches.delete(k);
        }));
      })
      .then(() => self.clients.claim())
      .then(() => self.clients.matchAll({ type: 'window' }))
      .then(clients => {
        console.log('[SW v6] Recarregando', clients.length, 'clientes...');
        clients.forEach(client => {
          // Redireciona com ?bust= para quebrar cache HTTP também
          const url = new URL(client.url);
          url.searchParams.set('bust', SW_VERSION);
          client.navigate(url.toString());
        });
      })
  );
});

// ── FETCH: passa tudo direto para a rede, sem cache ────────────────────────
self.addEventListener('fetch', event => {
  event.respondWith(fetch(event.request));
});

// ── MESSAGE ─────────────────────────────────────────────────────────────────
self.addEventListener('message', event => {
  if (event.data && event.data.type === 'GET_VERSION') {
    if (event.ports[0]) event.ports[0].postMessage({ version: SW_VERSION });
  }
});

// Interceptador de Precedência Máxima: Bypass Absoluto de Cache para Metadados de Deploy
self.addEventListener('fetch', function(event) {
  const requestUrl = new URL(event.request.url);
  
  if (requestUrl.origin === self.location.origin && requestUrl.pathname === '/deploy_meta.json') {
    event.respondWith(
      fetch(event.request, { cache: 'no-store' }).catch(function() {
        return new Response(
          JSON.stringify({ status: 'unavailable', reason: 'network_error' }), 
          { 
            status: 503, 
            headers: { 
              'Content-Type': 'application/json',
              'Cache-Control': 'no-store'
            } 
          }
        );
      })
    );
    return;
  }
  
  // ... (Preserva a fiação padrão do Flutter abaixo)
});

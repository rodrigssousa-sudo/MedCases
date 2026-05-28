# ── Dockerfile: nginx servindo build pré-compilado ────────────────────────────
# O Flutter web já foi compilado localmente e commitado em build/web/
# O DigitalOcean NÃO precisa instalar Flutter — apenas serve os arquivos estáticos

FROM nginx:1.25-alpine

# Remover config padrão
RUN rm /etc/nginx/conf.d/default.conf

# Copiar nossa config nginx customizada
COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf

# Copiar o build Flutter pré-compilado
COPY build/web /usr/share/nginx/html

# ── CRÍTICO: substituir o SW padrão do Flutter pelo destruidor customizado ────
# O flutter build web gera um flutter_service_worker.js com cache agressivo.
# Esse SW fica em cache no browser e interceta requests do Firebase → PlatformException.
# O SW destruidor (web/flutter_service_worker.js) apaga todos os caches ao instalar,
# quebrando o ciclo vicioso de cache stale. Deve ser aplicado SEMPRE após o COPY.
COPY web/flutter_service_worker.js /usr/share/nginx/html/flutter_service_worker.js

# ── PWA SW customizado: mantém a versão fonte acima do artifact build/web ─────
# Evita que um build/web commitado com pwa-sw.js antigo volte a servir bundle stale.
COPY web/pwa-sw.js /usr/share/nginx/html/pwa-sw.js

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:8080/health || exit 1

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]

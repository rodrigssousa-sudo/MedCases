# ══════════════════════════════════════════════════════════════════════════════
# Dockerfile — MedCases Pro — Multi-Stage Build
# Estágio 1: Compila o Flutter Web dentro do container
# Estágio 2: Serve os artefatos via Nginx com config customizada
# ══════════════════════════════════════════════════════════════════════════════

# ── Estágio 1: Build do Flutter Web (Debian oficial + Flutter clonado) ────────
FROM debian:stable-slim AS build-env

# Dependências essenciais do sistema
RUN apt-get update && apt-get install -y \
    curl git unzip xz-utils zip libglu1-mesa ca-certificates fontconfig fonts-dejavu-core \
    --no-install-recommends && rm -rf /var/lib/apt/lists/*

# Clona o Flutter diretamente do repositório oficial na versão exata 3.22.2
RUN git clone https://github.com/flutter/flutter.git -b 3.22.2 /flutter

ENV PATH="/flutter/bin:/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Pré-aquece o SDK e valida o setup
RUN flutter doctor

WORKDIR /app

# Copia todo o projeto
COPY . .

# Instala dependências e compila para Web
RUN flutter pub get
ENV DART_VM_OPTIONS="--old_gen_heap_size=1024"
RUN flutter build web --release --no-tree-shake-icons --workers=1

# ── Estágio 2: Servidor Nginx ──────────────────────────────────────────────────
FROM nginx:1.25.5-alpine

# Remove config padrão do Nginx
RUN rm /etc/nginx/conf.d/default.conf

# Copia nossa config Nginx customizada (anti-cache, SPA routing, health check)
COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf

# Copia os artefatos do Flutter Web compilados no estágio anterior
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Sobrescreve o Service Worker padrão do Flutter pelo destruidor customizado.
# O SW gerado pelo flutter build web usa cache agressivo que intercepta
# requests do Firebase → PlatformException. O SW customizado apaga todos
# os caches ao instalar, quebrando o ciclo de cache stale.
COPY web/flutter_service_worker.js /usr/share/nginx/html/flutter_service_worker.js

# Garante o PWA SW customizado sobre o artifact do build/web
COPY web/pwa-sw.js /usr/share/nginx/html/pwa-sw.js

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:8080/health || exit 1

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]

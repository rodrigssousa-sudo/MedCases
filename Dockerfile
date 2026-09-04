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

# DigitalOcean web build compatibility:
# Flutter 3.44.5 is required by the current dependency graph.
# In particular, the app pins characters 1.4.1; Flutter 3.27.4 pins
# flutter_test to characters 1.3.0 and causes pub version solving to fail.
RUN git clone https://github.com/flutter/flutter.git -b 3.44.5 /flutter

ENV PATH="/flutter/bin:/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Pré-aquece o SDK e valida o setup
RUN flutter doctor

WORKDIR /app

# Copia todo o projeto
COPY . .

# Instala dependências e compila para Web
RUN flutter pub get
# Limita heap do Dart VM a 1024MB para evitar OOM no container DigitalOcean
ENV DART_VM_OPTIONS="--old_gen_heap_size=1024"

# ── Build identity injection (MICRO-BUILD 462E-A.5.3.7.3.2.5.3.1) ───────────
# BUILD_COMMIT, BUNDLE_VERSION, BUILT_AT are captured at Docker build time and
# injected into the Dart VM via --dart-define. The Flutter app reads them via
# String.fromEnvironment() — no hardcoded SHA in source ever again.
# These ARGs can be overridden by DO App Platform build args or docker build --build-arg.
ARG BUILD_COMMIT=unknown
ARG BUNDLE_VERSION=dev
ARG BUILT_AT=unknown

# -O1: nível de otimização reduzido — menos RAM que O2/O3, suficiente para produção
RUN flutter build web --release --no-tree-shake-icons -O1 \
      --dart-define=BUILD_COMMIT="$BUILD_COMMIT" \
      --dart-define=BUNDLE_VERSION="$BUNDLE_VERSION" \
      --dart-define=BUILT_AT="$BUILT_AT"

# ── Estágio 2: Servidor Nginx ──────────────────────────────────────────────────
FROM nginx:1.25.5-alpine

# Remove config padrão do Nginx
RUN rm /etc/nginx/conf.d/default.conf

# Copia nossa config Nginx customizada (anti-cache, SPA routing, health check)
COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf

# ── PILAR 2: Runtime metadata bootstrapper ────────────────────────────────────
# Hooks into nginx:alpine's /docker-entrypoint.d/ initialization sequence.
# Runs BEFORE nginx starts — generates /deploy_meta.json from DO runtime env vars
# (DEPLOY_COMMIT = ${_self.COMMIT_SHA}, BUNDLE_VERSION from app.yaml envs).
# GEMINI_API_KEY is intentionally absent from this build scope — AI secrets
# belong exclusively to the ai-gateway service, never to the static web bundle.
COPY docker/40-generate-deploy-meta.sh /docker-entrypoint.d/40-generate-deploy-meta.sh
RUN chmod +x /docker-entrypoint.d/40-generate-deploy-meta.sh

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

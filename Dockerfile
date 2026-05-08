# ── Stage 1: Build Flutter Web ──────────────────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:3.24.0 AS builder

WORKDIR /app

# Copiar dependências primeiro (cache layer)
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copiar código fonte
COPY . .

# Build Flutter web release otimizado
RUN flutter build web --release \
    --dart-define=flutter.inspector.structuredErrors=false \
    --dart-define=debugShowCheckedModeBanner=false

# ── Stage 2: Nginx para servir arquivos estáticos ───────────────────────────
FROM nginx:1.25-alpine

# Remover config padrão do nginx
RUN rm /etc/nginx/conf.d/default.conf

# Copiar nossa config customizada
COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf

# Copiar build gerado pelo Flutter
COPY --from=builder /app/build/web /usr/share/nginx/html

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:8080/index.html || exit 1

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]

# ══════════════════════════════════════════════════════════════════════════════
# MedCases Pro — AI Gateway Server
# Dockerfile para Digital Ocean App Platform
# ══════════════════════════════════════════════════════════════════════════════

# ── Stage 1: dependencies ─────────────────────────────────────────────────────
FROM node:22-alpine AS deps

WORKDIR /app

# Copia apenas manifesto de dependências (aproveitamento de cache do Docker)
COPY package.json package-lock.json* ./

# Instala APENAS dependências de produção
RUN npm ci --omit=dev --no-audit --no-fund

# ── Stage 2: runtime ──────────────────────────────────────────────────────────
FROM node:22-alpine AS runtime

# Cria usuário não-root para segurança
RUN addgroup -g 1001 -S nodejs && \
    adduser  -u 1001 -S medcases -G nodejs

WORKDIR /app

# Copia dependências do stage anterior
COPY --from=deps --chown=medcases:nodejs /app/node_modules ./node_modules

# Copia código-fonte
COPY --chown=medcases:nodejs server.js audio_transcription_routes.js ./

# Variáveis de ambiente com defaults seguros
ENV NODE_ENV=production \
    PORT=8080 \
    LOG_LEVEL=info

# Expõe porta (Digital Ocean lê EXPOSE para roteamento)
EXPOSE 8080

# Health check interno do Docker
HEALTHCHECK \
    --interval=30s \
    --timeout=5s \
    --start-period=10s \
    --retries=3 \
  CMD wget -qO- http://localhost:8080/health || exit 1

# Executa como usuário não-root
USER medcases

# Entrypoint
CMD ["node", "server.js"]

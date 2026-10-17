# R15 approved-artifact delivery; build recipe recorded in coordinated manifest.
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

# R15: serve only the frozen, previously approved Web build. No Flutter rebuild.
ADD release-web-r15.tar.gz /usr/share/nginx/html/

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:8080/health || exit 1

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]

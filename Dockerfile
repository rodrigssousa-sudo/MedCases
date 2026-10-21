# R15 approved-artifact delivery; build recipe recorded in coordinated manifest.
FROM nginx:1.25.5-alpine@sha256:721fa00bc549df26b3e67cc558ff176112d4ba69847537766f3c28e171d180e7

# Remove config padrão do Nginx
RUN rm /etc/nginx/conf.d/default.conf

# Copia nossa config Nginx customizada (anti-cache, SPA routing, health check)
# Keep the app config separate from the base-image file removed above.
# A cached deletion of default.conf must never suppress the app listener.
COPY nginx/nginx.conf /etc/nginx/conf.d/medcases.conf
# The official image links /var/run to /run. Build validation must not depend
# on that transient directory. Keep the PID in nginx's existing root-owned cache dir,
# in both build and runtime, rather than creating or masking /var/run.
RUN test "$(id -u)" = 0 \
    && test -d /var/cache/nginx && test -w /var/cache/nginx \
    && grep -Eq '^pid[[:space:]]+/var/run/nginx.pid;' /etc/nginx/nginx.conf \
    && sed -i 's@/var/run/nginx.pid@/var/cache/nginx/nginx.pid@' /etc/nginx/nginx.conf \
    && test -s /etc/nginx/conf.d/medcases.conf \
    && nginx -t

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
  CMD wget -qO- http://127.0.0.1:8080/health || exit 1

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]

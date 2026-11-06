# Immutable delivery of the already frozen 7.0.3 (1728) Web payload.
# No Flutter compilation, Git HEAD lookup, clinical change or provider access.
FROM nginx:1.25.5-alpine@sha256:721fa00bc549df26b3e67cc558ff176112d4ba69847537766f3c28e171d180e7
# Overwrite the base config directly: no remove/copy whiteout dependency.
COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf
RUN test -s /etc/nginx/conf.d/default.conf \
    && test -d /var/cache/nginx && test -w /var/cache/nginx \
    && grep -Eq '^pid[[:space:]]+/var/run/nginx.pid;' /etc/nginx/nginx.conf \
    && sed -i 's@/var/run/nginx.pid@/var/cache/nginx/nginx.pid@' /etc/nginx/nginx.conf \
    && nginx -t
COPY docker/40-generate-deploy-meta.sh /docker-entrypoint.d/40-generate-deploy-meta.sh
RUN chmod +x /docker-entrypoint.d/40-generate-deploy-meta.sh
ADD release-web-703-1728.tar.gz /usr/share/nginx/html/
RUN test -s /usr/share/nginx/html/index.html \
    && test -s /usr/share/nginx/html/main.dart.js \
    && test -s /usr/share/nginx/html/flutter_bootstrap.js
ENV BUNDLE_VERSION=7.0.3+1728
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/health || exit 1
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]

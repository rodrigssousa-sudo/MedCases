#!/bin/sh
# ══════════════════════════════════════════════════════════════════════════════
# docker/40-generate-deploy-meta.sh
# MICRO-BUILD 462E-A.5.3.7.3.2.5.3.3 — PILAR 2
#
# Nginx entrypoint.d bootstrap script — runs BEFORE nginx starts.
# Generates /usr/share/nginx/html/deploy_meta.json at container boot time,
# embedding the runtime identity values injected by DO App Platform as env vars.
#
# Execution order: nginx:alpine runs all /docker-entrypoint.d/*.sh scripts
# in lexicographic order before starting nginx. File named 40-* runs after
# the nginx default 10-listen-on-ipv6-by-default.sh and 20-envsubst-on-templates.sh.
#
# Contract:
#   DEPLOY_COMMIT  — required; provided by DO App Platform ${_self.COMMIT_HASH}
#   BUNDLE_VERSION — optional; defaults to 1.0.0+3467
# ══════════════════════════════════════════════════════════════════════════════
set -e

TARGET_FILE="/usr/share/nginx/html/deploy_meta.json"
CURRENT_UTC_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ── Fail-fast constraint validation gate ──────────────────────────────────────
if [ -z "$DEPLOY_COMMIT" ]; then
  echo "[DEPLOY_METADATA][ERROR] DEPLOY_COMMIT environment variable is empty. Aborting boot." >&2
  exit 1
fi

# ── Atomic production JSON write ──────────────────────────────────────────────
# Single echo → single write — no partial-file risk.
# BUNDLE_VERSION defaults to 1.0.0+3467 if not injected by DO build pipeline.
echo "{\"deployCommit\":\"$DEPLOY_COMMIT\",\"bundleVersion\":\"${BUNDLE_VERSION:-1.0.0+3467}\",\"containerStartedAt\":\"$CURRENT_UTC_TIME\"}" \
  > "$TARGET_FILE"

echo "[DEPLOY_METADATA][SUCCESS] Generated runtime metadata mapping at $TARGET_FILE"

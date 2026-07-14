#!/bin/sh
# ══════════════════════════════════════════════════════════════════════════════
# docker/40-generate-deploy-meta.sh
# MICRO-BUILD 462E-A.5.3.7.3.2.5.3.4-AVAILABILITY-FIRST — T1
#
# Nginx entrypoint.d bootstrap script — runs BEFORE nginx starts.
# Generates /usr/share/nginx/html/deploy_meta.json at container boot time,
# embedding the runtime identity values injected by DO App Platform as env vars.
#
# Execution order: nginx:alpine runs all /docker-entrypoint.d/*.sh scripts
# in lexicographic order before starting nginx. File named 40-* runs after
# the nginx default 10-listen-on-ipv6-by-default.sh and 20-envsubst-on-templates.sh.
#
# FAIL-OPEN CONTRACT:
#   This script MUST NEVER crash the container due to missing telemetry.
#   On VALID DEPLOY_COMMIT  → status:"available"  + real metadata + [SUCCESS] log.
#   On INVALID/placeholder  → status:"unavailable" + null deployCommit + [WARNING] log + exit 0.
#
# Inputs (env vars, injected by DO App Platform at container boot):
#   DEPLOY_COMMIT  — git SHA from ${_self.COMMIT_SHA}; validated hex 40-64 chars
#   BUNDLE_VERSION — semantic version string; defaults to 1.0.0+3467 if absent
# ══════════════════════════════════════════════════════════════════════════════
set -e

TARGET_FILE="/usr/share/nginx/html/deploy_meta.json"
TEMP_FILE="/usr/share/nginx/html/.deploy_meta.tmp.$$"

# ── Cleanup trap — removes temp file on any exit/interrupt/termination ────────
trap 'rm -f "$TEMP_FILE"' EXIT INT TERM

CURRENT_UTC_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
RESOLVED_BUNDLE="${BUNDLE_VERSION:-1.0.0+3467}"

# ── Helper: write unavailable JSON atomically and exit 0 ──────────────────────
write_unavailable() {
  local reason="$1"
  printf '{"status":"unavailable","deployCommit":null,"bundleVersion":"%s","containerStartedAt":"%s"}\n' \
    "$RESOLVED_BUNDLE" "$CURRENT_UTC_TIME" > "$TEMP_FILE"
  mv -f "$TEMP_FILE" "$TARGET_FILE"
  echo "[DEPLOY_METADATA][WARNING] $reason — writing status:unavailable to $TARGET_FILE"
  # Trap is still active; EXIT trap removes TEMP_FILE if it wasn't moved (no-op here).
  # Exit 0: container NEVER crashes for missing telemetry.
  exit 0
}

# ── STEP 1: Filter blank / whitespace-only values ────────────────────────────
RAW="${DEPLOY_COMMIT}"

# Strip leading/trailing whitespace (POSIX-safe via echo)
TRIMMED=$(printf '%s' "$RAW" | tr -d '[:space:]')

if [ -z "$TRIMMED" ]; then
  write_unavailable "DEPLOY_COMMIT is empty or whitespace-only"
fi

# ── STEP 2: Filter known placeholder literals ──────────────────────────────────
case "$TRIMMED" in
  unknown|\
  null|\
  'null'|\
  '${_self.COMMIT_HASH}'|\
  '${_self.COMMIT_SHA}'|\
  '\${_self.COMMIT_HASH}'|\
  '\${_self.COMMIT_SHA}')
    write_unavailable "DEPLOY_COMMIT is a placeholder literal: '$TRIMMED'"
    ;;
esac

# ── STEP 3: Strict hexadecimal SHA regex validation ───────────────────────────
# Accepts 40-64 hex characters (SHA-1 40, SHA-256 64).
# POSIX sh: use 'case' pattern matching as a portable regex alternative.
# Validate that TRIMMED contains ONLY hex chars and has correct length.

# Length check (40 ≤ len ≤ 64)
SHA_LEN=$(printf '%s' "$TRIMMED" | wc -c | tr -d ' ')
if [ "$SHA_LEN" -lt 40 ] || [ "$SHA_LEN" -gt 64 ]; then
  write_unavailable "DEPLOY_COMMIT length $SHA_LEN is outside valid range [40,64]: '$TRIMMED'"
fi

# Character class check — POSIX grep with BRE: only hex digits
if ! printf '%s' "$TRIMMED" | grep -qE '^[0-9a-fA-F]{40,64}$'; then
  write_unavailable "DEPLOY_COMMIT failed hex validation: '$TRIMMED'"
fi

# ── STEP 4: VALID path — write status:"available" atomically ─────────────────
printf '{"status":"available","deployCommit":"%s","bundleVersion":"%s","containerStartedAt":"%s"}\n' \
  "$TRIMMED" "$RESOLVED_BUNDLE" "$CURRENT_UTC_TIME" > "$TEMP_FILE"

mv -f "$TEMP_FILE" "$TARGET_FILE"

echo "[DEPLOY_METADATA][SUCCESS] Runtime metadata written to $TARGET_FILE"
echo "[DEPLOY_METADATA][SUCCESS] deployCommit=${TRIMMED} bundleVersion=${RESOLVED_BUNDLE} containerStartedAt=${CURRENT_UTC_TIME}"

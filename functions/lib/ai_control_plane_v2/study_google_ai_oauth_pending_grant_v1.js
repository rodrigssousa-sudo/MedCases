'use strict';

const crypto = require('crypto');

const DEFAULT_PENDING_TTL_MS = 10 * 60 * 1000;

function requireNonEmptyString(value, name) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new TypeError(`${name}_REQUIRED`);
  }
  return value.trim();
}

function sha256Hex(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex');
}

function base64Url(buffer) {
  return Buffer.from(buffer)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function safeProjects(projects) {
  const seen = new Set();
  const out = [];
  for (const project of Array.isArray(projects) ? projects : []) {
    if (!project || typeof project !== 'object') continue;
    const projectId = typeof project.projectId === 'string' ? project.projectId.trim() : '';
    if (!projectId || seen.has(projectId)) continue;
    seen.add(projectId);
    out.push(Object.freeze({
      projectId,
      projectNumber:
        typeof project.projectNumber === 'string' && project.projectNumber.trim()
          ? project.projectNumber.trim()
          : null,
      displayName:
        typeof project.displayName === 'string' && project.displayName.trim()
          ? project.displayName.trim()
          : null,
    }));
  }
  return Object.freeze(out);
}

function safeScopes(scopes) {
  return Object.freeze(
    Array.from(
      new Set(
        (Array.isArray(scopes) ? scopes : [])
          .filter((x) => typeof x === 'string')
          .map((x) => x.trim())
          .filter(Boolean),
      ),
    ).sort(),
  );
}

function pendingAadProjectBinding(selectionIdSha256) {
  const hash = requireNonEmptyString(selectionIdSha256, 'SELECTION_ID_SHA256');
  if (!/^[a-f0-9]{64}$/.test(hash)) {
    throw new Error('SELECTION_ID_SHA256_INVALID');
  }
  return `__medcases_pending_oauth__:${hash}`;
}

class StudyGoogleAiOAuthPendingGrantV1 {
  constructor({
    kmsAdapter,
    store,
    randomBytes,
    clock,
    ttlMs = DEFAULT_PENDING_TTL_MS,
  }) {
    if (
      !kmsAdapter ||
      typeof kmsAdapter.encryptRefreshToken !== 'function' ||
      typeof kmsAdapter.decryptRefreshToken !== 'function'
    ) {
      throw new TypeError('KMS_ADAPTER_REQUIRED');
    }
    if (
      !store ||
      typeof store.createPendingGrant !== 'function' ||
      typeof store.consumePendingGrant !== 'function'
    ) {
      throw new TypeError('PENDING_GRANT_STORE_REQUIRED');
    }
    const ttl = Number(ttlMs);
    if (!Number.isFinite(ttl) || ttl < 60_000 || ttl > 30 * 60_000) {
      throw new Error('PENDING_GRANT_TTL_OUT_OF_RANGE');
    }

    this.kmsAdapter = kmsAdapter;
    this.store = store;
    this.randomBytes =
      typeof randomBytes === 'function' ? randomBytes : crypto.randomBytes;
    this.clock = typeof clock === 'function' ? clock : Date.now;
    this.ttlMs = ttl;
  }

  async createPendingGrant({
    medcasesUid,
    refreshToken,
    discoveredProjects,
    grantedScopes,
  }) {
    const uid = requireNonEmptyString(medcasesUid, 'MEDCASES_UID');
    const token = requireNonEmptyString(refreshToken, 'REFRESH_TOKEN');
    const projects = safeProjects(discoveredProjects);

    if (projects.length < 2) {
      throw new Error('MULTI_PROJECT_PENDING_GRANT_REQUIRES_AT_LEAST_TWO_PROJECTS');
    }

    const selectionId = base64Url(this.randomBytes(24));
    if (selectionId.length < 24) {
      throw new Error('OPAQUE_SELECTION_ID_TOO_SHORT');
    }

    const selectionIdSha256 = sha256Hex(selectionId);
    const createdAtMs = Number(this.clock());
    const expiresAtMs = createdAtMs + this.ttlMs;
    const pendingBinding = pendingAadProjectBinding(selectionIdSha256);

    const encryptedRefreshToken =
      await this.kmsAdapter.encryptRefreshToken({
        refreshToken: token,
        medcasesUid: uid,
        projectId: pendingBinding,
      });

    await this.store.createPendingGrant({
      medcasesUid: uid,
      selectionIdSha256,
      encryptedRefreshToken,
      discoveredProjects: projects,
      grantedScopes: safeScopes(grantedScopes),
      createdAtMs,
      expiresAtMs,
    });

    return Object.freeze({
      selectionId,
      expiresAtMs,
      discoveredProjects: projects,
    });
  }

  async consumePendingGrant({
    medcasesUid,
    selectionId,
    selectedProjectId,
  }) {
    const uid = requireNonEmptyString(medcasesUid, 'MEDCASES_UID');
    const opaque = requireNonEmptyString(selectionId, 'SELECTION_ID');
    const selected = requireNonEmptyString(selectedProjectId, 'SELECTED_PROJECT_ID');
    const selectionIdSha256 = sha256Hex(opaque);
    const claimId = base64Url(this.randomBytes(24));
    const claimIdSha256 = sha256Hex(claimId);

    const record = await this.store.consumePendingGrant({
      medcasesUid: uid,
      selectionIdSha256,
      selectedProjectId: selected,
      claimIdSha256,
    });

    const hardenedLifecycle = Boolean(
      record &&
      record.claimed === true &&
      typeof this.store.completePendingGrant === 'function' &&
      typeof this.store.releasePendingGrantClaim === 'function'
    );

    if (
      !record ||
      (hardenedLifecycle !== true && record.consumed !== true)
    ) {
      throw new Error('PENDING_GRANT_NOT_CLAIMED_OR_CONSUMED');
    }

    const projects = safeProjects(record.discoveredProjects);
    if (!projects.some((p) => p.projectId === selected)) {
      if (hardenedLifecycle) {
        await this.store.releasePendingGrantClaim({
          medcasesUid: uid,
          selectionIdSha256,
          claimIdSha256,
        });
      }
      throw new Error('SELECTED_PROJECT_NOT_IN_PENDING_DISCOVERY');
    }

    let refreshToken;
    try {
      refreshToken = await this.kmsAdapter.decryptRefreshToken({
        encryptedRecord: record.encryptedRefreshToken,
        medcasesUid: uid,
        projectId: pendingAadProjectBinding(selectionIdSha256),
      });
    } catch (error) {
      if (hardenedLifecycle) {
        try {
          await this.store.releasePendingGrantClaim({
            medcasesUid: uid,
            selectionIdSha256,
            claimIdSha256,
          });
        } catch (_) {
          // Preserve the original decrypt failure; lease expiry remains a safe retry path.
        }
      }
      throw error;
    }

    const completePendingGrant = hardenedLifecycle
      ? () => this.store.completePendingGrant({
          medcasesUid: uid,
          selectionIdSha256,
          selectedProjectId: selected,
          claimIdSha256,
        })
      : null;

    const releasePendingGrantClaim = hardenedLifecycle
      ? () => this.store.releasePendingGrantClaim({
          medcasesUid: uid,
          selectionIdSha256,
          claimIdSha256,
        })
      : null;

    return Object.freeze({
      refreshToken: requireNonEmptyString(refreshToken, 'REFRESH_TOKEN'),
      selectedProjectId: selected,
      discoveredProjects: projects,
      grantedScopes: safeScopes(record.grantedScopes),
      pendingLifecycleHardened: hardenedLifecycle,
      completePendingGrant,
      releasePendingGrantClaim,
    });
  }
}

module.exports = {
  DEFAULT_PENDING_TTL_MS,
  StudyGoogleAiOAuthPendingGrantV1,
  pendingAadProjectBinding,
  safeProjects,
  safeScopes,
  sha256Hex,
};

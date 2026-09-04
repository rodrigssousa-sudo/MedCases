'use strict';

const crypto = require('crypto');
const http = require('http');
const admin = require('firebase-admin');

const {
  exchangeWithBoundSecret,
} = require('./study_google_ai_oauth_token_exchange_secret_bound_v1');
const {
  persistEncryptedOAuthGrant,
} = require('./study_google_ai_oauth_refresh_token_project_vault_v1');
const {
  createStudyGoogleAiOAuthRuntimeCompositionInertV1,
} = require('./study_google_ai_oauth_runtime_composition_inert_v1');
const {
  StudyGoogleAiOAuthPendingGrantV1,
} = require('./study_google_ai_oauth_pending_grant_v1');
const {
  StudyGoogleAiOAuthPendingGrantFirestoreStoreV1,
} = require('./study_google_ai_oauth_pending_grant_firestore_store_v1');
const {
  createRefreshAccessTokenV1,
} = require('./study_google_ai_oauth_refresh_access_token_secret_bound_v1');
const {
  createStudyGoogleAiOAuthTwoPhasePhysicalCanaryOrchestratorV1,
} = require('./study_google_ai_oauth_two_phase_physical_canary_orchestrator_inert_v1');

const VERSION =
  'medcases.study.oauth.physical-canary-http-server.v1';

const REQUIRED_SCOPES = Object.freeze([
  'https://www.googleapis.com/auth/cloud-platform',
  'https://www.googleapis.com/auth/generative-language.retriever',
]);

function cleanString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function sha256Hex(value) {
  return crypto
    .createHash('sha256')
    .update(String(value), 'utf8')
    .digest('hex');
}

function constantTimeHexEquals(left, right) {
  const a = Buffer.from(cleanString(left), 'utf8');
  const b = Buffer.from(cleanString(right), 'utf8');
  if (a.length === 0 || a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

function safeJson(res, status, payload) {
  const body = JSON.stringify(payload);
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('Pragma', 'no-cache');
  res.end(body);
}

async function readJson(req, maxBytes = 32768) {
  const chunks = [];
  let size = 0;

  for await (const chunk of req) {
    size += chunk.length;
    if (size > maxBytes) {
      const error = new Error('REQUEST_BODY_TOO_LARGE');
      error.httpStatus = 413;
      throw error;
    }
    chunks.push(chunk);
  }

  if (chunks.length === 0) return {};

  try {
    const parsed = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      throw new Error('REQUEST_JSON_OBJECT_REQUIRED');
    }
    return parsed;
  } catch (error) {
    if (error && error.message === 'REQUEST_JSON_OBJECT_REQUIRED') {
      error.httpStatus = 400;
      throw error;
    }
    const wrapped = new Error('REQUEST_JSON_INVALID');
    wrapped.httpStatus = 400;
    throw wrapped;
  }
}

function bearerToken(req) {
  const header = cleanString(req && req.headers && req.headers.authorization);
  const match = /^Bearer\s+(.+)$/i.exec(header);
  return match ? cleanString(match[1]) : '';
}

function armToken(req) {
  return cleanString(
    req && req.headers && req.headers['x-medcases-canary-arm']
  );
}

function createPhysicalCanaryHttpHandler({
  verifyFirebaseIdToken,
  issueOAuthFlowChallenge,
  createOrchestrator,
  webClientId,
  expectedArmSha256,
} = {}) {
  if (typeof verifyFirebaseIdToken !== 'function') {
    throw new TypeError('FIREBASE_ID_TOKEN_VERIFIER_REQUIRED');
  }
  if (typeof issueOAuthFlowChallenge !== 'function') {
    throw new TypeError('FLOW_CHALLENGE_ISSUER_REQUIRED');
  }
  if (typeof createOrchestrator !== 'function') {
    throw new TypeError('ORCHESTRATOR_FACTORY_REQUIRED');
  }

  const clientId = cleanString(webClientId);
  if (!clientId.endsWith('.apps.googleusercontent.com')) {
    throw new Error('WEB_CLIENT_ID_INVALID');
  }

  const armSha = cleanString(expectedArmSha256);
  if (!/^[a-f0-9]{64}$/.test(armSha)) {
    throw new Error('CANARY_ARM_SHA256_INVALID');
  }

  return async function physicalCanaryHttpHandler(req, res) {
    try {
      if (req.method !== 'POST') {
        safeJson(res, 405, {
          ok: false,
          version: VERSION,
          safeReason: 'method_not_allowed',
        });
        return;
      }

      const firebaseToken = bearerToken(req);
      if (!firebaseToken) {
        safeJson(res, 401, {
          ok: false,
          version: VERSION,
          safeReason: 'firebase_auth_required',
        });
        return;
      }

      let decoded;
      try {
        decoded = await verifyFirebaseIdToken(firebaseToken);
      } catch (_) {
        safeJson(res, 401, {
          ok: false,
          version: VERSION,
          safeReason: 'firebase_auth_invalid',
        });
        return;
      }

      const uid = cleanString(decoded && decoded.uid);
      if (!uid) {
        safeJson(res, 401, {
          ok: false,
          version: VERSION,
          safeReason: 'firebase_uid_missing',
        });
        return;
      }

      const providedArm = armToken(req);
      if (
        !providedArm ||
        !constantTimeHexEquals(sha256Hex(providedArm), armSha)
      ) {
        safeJson(res, 403, {
          ok: false,
          version: VERSION,
          safeReason: 'canary_arm_rejected',
        });
        return;
      }

      const body = await readJson(req);
      const action = cleanString(body.action);

      if (action === 'issue') {
        const challenge = await issueOAuthFlowChallenge({
          medcasesUid: uid,
        });

        safeJson(res, 200, {
          ok: true,
          version: VERSION,
          action: 'issue',
          challengeId: challenge.challengeId,
          state: challenge.state,
          nonce: challenge.nonce,
          expiresAtMs: challenge.expiresAtMs,
          oauth: {
            webClientId: clientId,
            scopes: REQUIRED_SCOPES,
            forceCodeForRefreshToken: true,
          },
          generalStudyTrafficEnabled: false,
        });
        return;
      }

      if (action === 'exchange') {
        const orchestrator = createOrchestrator({ medcasesUid: uid });
        const result = await orchestrator({
          medcasesUid: uid,
          challengeId: cleanString(body.challengeId),
          state: cleanString(body.state),
          nonce: cleanString(body.nonce),
          serverAuthorizationCode: cleanString(body.serverAuthorizationCode),
          requestedProjectId: cleanString(body.requestedProjectId),
          selectionId: cleanString(body.selectionId),
        });

        const status = result && result.accepted === true ? 200 : 409;
        safeJson(res, status, {
          ok: result && result.accepted === true,
          version: VERSION,
          action: 'exchange',
          result,
          generalStudyTrafficEnabled: false,
        });
        return;
      }

      safeJson(res, 400, {
        ok: false,
        version: VERSION,
        safeReason: 'unknown_action',
      });
    } catch (error) {
      const safeReason = cleanString(error && error.message) || 'canary_error';
      const status =
        Number(error && error.httpStatus) >= 400 &&
        Number(error && error.httpStatus) <= 599
          ? Number(error.httpStatus)
          : 500;

      const payload = {
        ok: false,
        version: VERSION,
        safeReason,
        generalStudyTrafficEnabled: false,
      };

      if (
        error &&
        typeof error.safeOAuthError === 'string' &&
        error.safeOAuthError
      ) {
        payload.safeOAuthError = error.safeOAuthError;
      }

      safeJson(res, status, payload);
    }
  };
}

function createProductionServer() {
  const projectId = cleanString(
    process.env.MEDCASES_CANARY_PROJECT || process.env.GOOGLE_CLOUD_PROJECT
  );
  const webClientId = cleanString(
    process.env.MEDCASES_CANARY_WEB_CLIENT_ID
  );
  const expectedArmSha256 = cleanString(
    process.env.MEDCASES_PHYSICAL_CANARY_ARM_SHA256
  );
  const kmsKeyName = cleanString(
    process.env.MEDCASES_CANARY_KMS_KEY
  );
  const clientSecret = cleanString(
    process.env.MEDCASES_STUDY_GOOGLE_OAUTH_WEB_CLIENT_SECRET_V1
  );

  if (
    process.env.MEDCASES_PHYSICAL_CANARY_ENABLED !== 'true'
  ) {
    throw new Error('PHYSICAL_CANARY_SERVICE_NOT_ARMED');
  }

  if (!admin.apps.length) {
    admin.initializeApp({ projectId });
  }

  const runtime =
    createStudyGoogleAiOAuthRuntimeCompositionInertV1({
      projectId,
      kmsKeyName,
    });

  const verifyFirebaseIdToken =
    async (idToken) => admin.auth().verifyIdToken(idToken);

  const fetchImpl = globalThis.fetch;
  if (typeof fetchImpl !== 'function') {
    throw new Error('GLOBAL_FETCH_REQUIRED');
  }

  const pendingStore =
    new StudyGoogleAiOAuthPendingGrantFirestoreStoreV1({
      firestore: admin.firestore(),
    });

  const pendingGrant = new StudyGoogleAiOAuthPendingGrantV1({
    kmsAdapter: runtime.pendingGrantKmsAdapter,
    store: pendingStore,
  });

  const refreshAccessToken = createRefreshAccessTokenV1({
    fetchImpl: fetchImpl.bind(globalThis),
    clientId: webClientId,
    clientSecret,
  });

  const createOrchestrator = ({ medcasesUid }) =>
    createStudyGoogleAiOAuthTwoPhasePhysicalCanaryOrchestratorV1({
      consumeOAuthFlowChallenge: (input) =>
        runtime.consumeOAuthFlowChallenge(input),

      exchangeAuthorizationCode: ({
        serverAuthorizationCode,
        redirectUri,
      }) =>
        exchangeWithBoundSecret({
          serverAuthorizationCode,
          clientId: webClientId,
          redirectUri,
          env: process.env,
        }),

      discoverProjects: ({ accessToken }) =>
        runtime.discoverProjects({ accessToken }),

      validateProject: async ({
        accessToken,
        requestedProjectId,
      }) => {
        const projectIdValidated =
          await runtime.resolveValidatedUserProjectId({
            accessToken,
            medCasesUid: medcasesUid,
            serverSelectedProjectId: requestedProjectId,
          });

        return {
          serverValidated: true,
          projectId: projectIdValidated,
          geminiApiEnabled: true,
          serviceUsageUse: true,
        };
      },

      persistEncryptedGrant: async (input) => {
        const persistence = await persistEncryptedOAuthGrant({
          ...input,
          encryptRefreshToken: runtime.encryptRefreshToken,
          storeEncryptedGrant: runtime.storeEncryptedGrant,
        });

        return {
          ...persistence,
          encrypted:
            persistence &&
            persistence.encryptedRefreshTokenPresent === true,
        };
      },

      createPendingGrant: (input) =>
        pendingGrant.createPendingGrant(input),

      consumePendingGrant: (input) =>
        pendingGrant.consumePendingGrant(input),

      refreshAccessToken,
    });

  const handler = createPhysicalCanaryHttpHandler({
    verifyFirebaseIdToken,
    issueOAuthFlowChallenge: runtime.issueOAuthFlowChallenge,
    createOrchestrator,
    webClientId,
    expectedArmSha256,
  });

  return http.createServer(handler);
}

if (require.main === module) {
  const port = Number(process.env.PORT || 8080);
  const server = createProductionServer();
  server.listen(port, '0.0.0.0');
}

module.exports = {
  VERSION,
  REQUIRED_SCOPES,
  armToken,
  bearerToken,
  constantTimeHexEquals,
  createPhysicalCanaryHttpHandler,
  createProductionServer,
  readJson,
  sha256Hex,
};

'use strict';

const {
  inspectStudyGoogleAiAuthCodeInert,
} = require('./study_google_ai_oauth_exchange_inert_v1');

const {
  CLIENT_SECRET_ENV,
  exchangeWithBoundSecret,
} = require('./study_google_ai_oauth_token_exchange_secret_bound_v1');

const TOKEN_EXCHANGE_ENABLED = false;

const {
  persistEncryptedOAuthGrant,
} = require('./study_google_ai_oauth_refresh_token_project_vault_v1');

const TOKEN_PERSISTENCE_ENABLED = false;

const {
  createStudyGoogleAiOAuthRuntimeCompositionInertV1,
} = require('./study_google_ai_oauth_runtime_composition_inert_v1');

const RUNTIME_ADAPTER_WIRING_ENABLED = false;
const FLOW_GUARD_ENFORCEMENT_ENABLED = false;

const VERSION =
  'medcases_study_google_ai_oauth_exchange_endpoint_inert_v1';

function safeBearerToken(req) {
  const headers =
    req && req.headers && typeof req.headers === 'object'
      ? req.headers
      : {};

  const raw =
    typeof headers.authorization === 'string'
      ? headers.authorization.trim()
      : '';

  if (!raw.toLowerCase().startsWith('bearer ')) {
    return '';
  }

  return raw.slice(7).trim();
}

function safeBody(req) {
  return req && req.body && typeof req.body === 'object'
    ? req.body
    : {};
}

function writeJson(res, statusCode, payload) {
  if (res && typeof res.set === 'function') {
    res.set('Cache-Control', 'no-store');
  }

  if (res && typeof res.status === 'function') {
    const chained = res.status(statusCode);

    if (chained && typeof chained.json === 'function') {
      return chained.json(payload);
    }
  }

  throw new Error('INVALID_RESPONSE_ADAPTER');
}

function createStudyGoogleAiOAuthExchangeEndpointInert({
  verifyIdToken,
  exchangeEnabled = TOKEN_EXCHANGE_ENABLED,
  exchangeAuthorizationCode = exchangeWithBoundSecret,
  tokenPersistenceEnabled = TOKEN_PERSISTENCE_ENABLED,
  runtimeWiringEnabled = RUNTIME_ADAPTER_WIRING_ENABLED,
  flowGuardEnabled = FLOW_GUARD_ENFORCEMENT_ENABLED,
  runtimeFactory = createStudyGoogleAiOAuthRuntimeCompositionInertV1,
  resolveValidatedUserProjectId,
  consumeOAuthFlowChallenge,
  persistOAuthGrant = persistEncryptedOAuthGrant,
  encryptRefreshToken,
  storeEncryptedGrant,
  publicWebClientId = '',
  secretEnv = process.env,
} = {}) {
  if (typeof verifyIdToken !== 'function') {
    throw new TypeError('verifyIdToken function is required');
  }

  return async function studyGoogleAiOAuthExchangeEndpointInert(
    req,
    res
  ) {
    if (!req || req.method !== 'POST') {
      return writeJson(res, 405, {
        version: VERSION,
        enabled: false,
        inert: true,
        accepted: false,
        safeReason: 'method_not_allowed',
      });
    }

    const firebaseIdToken = safeBearerToken(req);

    if (!firebaseIdToken) {
      return writeJson(res, 401, {
        version: VERSION,
        enabled: false,
        inert: true,
        accepted: false,
        safeReason: 'firebase_auth_required',
      });
    }

    let decoded;

    try {
      decoded = await verifyIdToken(firebaseIdToken);
    } catch (_) {
      return writeJson(res, 401, {
        version: VERSION,
        enabled: false,
        inert: true,
        accepted: false,
        safeReason: 'firebase_auth_invalid',
      });
    }

    const authenticatedUid =
      decoded && typeof decoded.uid === 'string'
        ? decoded.uid.trim()
        : '';

    const body = safeBody(req);

    const inspection =
      inspectStudyGoogleAiAuthCodeInert({
        authenticatedUid,
        requestedUid:
          typeof body.medCasesUid === 'string'
            ? body.medCasesUid
            : '',
        serverAuthorizationCode:
          typeof body.serverAuthorizationCode === 'string'
            ? body.serverAuthorizationCode
            : '',
        nonce:
          typeof body.nonce === 'string'
            ? body.nonce
            : '',
      });

    if (!exchangeEnabled) {
      return writeJson(res, 503, {
        version: VERSION,
        enabled: false,
        inert: true,
        accepted: false,

        authenticated: inspection.authenticated,
        uidMatches: inspection.uidMatches,
        codePresent: inspection.codePresent,
        noncePresent: inspection.noncePresent,

        authorizationCodeReturned: false,
        authorizationCodePersisted: false,
        authorizationCodeLogged: false,

        tokenExchangeAttempted: false,
        accessTokenReturned: false,
        refreshTokenReturned: false,
        tokenPersisted: false,

        providerCallAttempted: false,
        geminiAuthority: false,

        secretBindingRequired: true,
        secretEnvName: CLIENT_SECRET_ENV,

        safeReason: inspection.safeReason,
      });
    }

    if (
      !inspection.authenticated ||
      !inspection.uidMatches ||
      !inspection.codePresent ||
      !inspection.noncePresent
    ) {
      return writeJson(res, 400, {
        version: VERSION,
        enabled: true,
        inert: false,
        accepted: false,
        tokenExchangeAttempted: false,
        accessTokenReturned: false,
        refreshTokenReturned: false,
        tokenPersisted: false,
        providerCallAttempted: false,
        geminiAuthority: false,
        safeReason: inspection.safeReason,
      });
    }

    let effectiveResolveValidatedUserProjectId =
      resolveValidatedUserProjectId;
    let effectiveEncryptRefreshToken =
      encryptRefreshToken;
    let effectiveStoreEncryptedGrant =
      storeEncryptedGrant;
    let effectiveConsumeOAuthFlowChallenge =
      consumeOAuthFlowChallenge;

    if (runtimeWiringEnabled) {
      if (
        !exchangeEnabled ||
        !tokenPersistenceEnabled ||
        !flowGuardEnabled
      ) {
        return writeJson(res, 503, {
          version: VERSION,
          enabled: false,
          inert: true,
          accepted: false,
          tokenExchangeAttempted: false,
          tokenPersisted: false,
          providerCallAttempted: false,
          geminiAuthority: false,
          safeReason:
            'runtime_wiring_requires_exchange_persistence_and_flow_guard',
        });
      }

      if (typeof runtimeFactory !== 'function') {
        return writeJson(res, 503, {
          version: VERSION,
          enabled: false,
          inert: true,
          accepted: false,
          tokenExchangeAttempted: false,
          tokenPersisted: false,
          providerCallAttempted: false,
          geminiAuthority: false,
          safeReason:
            'runtime_factory_missing',
        });
      }

      const runtime = runtimeFactory();
      if (!runtime || typeof runtime !== 'object') {
        return writeJson(res, 503, {
          version: VERSION,
          enabled: false,
          inert: true,
          accepted: false,
          tokenExchangeAttempted: false,
          tokenPersisted: false,
          providerCallAttempted: false,
          geminiAuthority: false,
          safeReason:
            'runtime_factory_invalid',
        });
      }

      effectiveResolveValidatedUserProjectId =
        runtime.resolveValidatedUserProjectId;
      effectiveEncryptRefreshToken =
        runtime.encryptRefreshToken;
      effectiveStoreEncryptedGrant =
        runtime.storeEncryptedGrant;
      effectiveConsumeOAuthFlowChallenge =
        runtime.consumeOAuthFlowChallenge;
    }

    if (flowGuardEnabled) {
      if (
        typeof effectiveConsumeOAuthFlowChallenge
        !== 'function'
      ) {
        return writeJson(res, 503, {
          version: VERSION,
          enabled: true,
          inert: true,
          accepted: false,
          tokenExchangeAttempted: false,
          tokenPersisted: false,
          providerCallAttempted: false,
          geminiAuthority: false,
          safeReason:
            'flow_guard_runtime_missing',
        });
      }

      const challengeId =
        typeof body.challengeId === 'string'
          ? body.challengeId.trim()
          : '';
      const state =
        typeof body.state === 'string'
          ? body.state.trim()
          : '';

      if (!challengeId || !state) {
        return writeJson(res, 400, {
          version: VERSION,
          enabled: true,
          inert: true,
          accepted: false,
          tokenExchangeAttempted: false,
          tokenPersisted: false,
          providerCallAttempted: false,
          geminiAuthority: false,
          safeReason:
            'flow_guard_challenge_or_state_missing',
        });
      }

      const consumed =
        await effectiveConsumeOAuthFlowChallenge({
          medcasesUid:
            authenticatedUid,
          challengeId,
          state,
          nonce:
            body.nonce,
          authCode:
            body.serverAuthorizationCode,
        });

      if (!consumed || consumed.consumed !== true) {
        return writeJson(res, 409, {
          version: VERSION,
          enabled: true,
          inert: true,
          accepted: false,
          tokenExchangeAttempted: false,
          tokenPersisted: false,
          providerCallAttempted: false,
          geminiAuthority: false,
          safeReason:
            'flow_guard_not_consumed',
        });
      }
    }

    const tokenSet =
      await exchangeAuthorizationCode({
        serverAuthorizationCode:
          body.serverAuthorizationCode,
        clientId: publicWebClientId,
        redirectUri: '',
        env: secretEnv,
      });

    if (!tokenPersistenceEnabled) {
      return writeJson(res, 503, {
        version: VERSION,
        enabled: true,
        inert: true,
        accepted: false,

        authenticated: true,
        uidMatches: true,
        codePresent: true,
        noncePresent: true,

        authorizationCodeReturned: false,
        authorizationCodePersisted: false,
        authorizationCodeLogged: false,

        tokenExchangeAttempted: true,
        accessTokenReturned: false,
        refreshTokenReturned: false,
        tokenPersisted: false,

        providerCallAttempted: false,
        geminiAuthority: false,

        accessTokenPresent:
          Boolean(tokenSet.accessToken),
        refreshTokenPresent:
          Boolean(tokenSet.refreshToken),

        safeReason:
          'token_persistence_not_enabled',
      });
    }

    if (
      typeof effectiveResolveValidatedUserProjectId
      !== 'function'
    ) {
      return writeJson(res, 503, {
        version: VERSION,
        enabled: true,
        inert: true,
        accepted: false,
        tokenExchangeAttempted: true,
        tokenPersisted: false,
        accessTokenReturned: false,
        refreshTokenReturned: false,
        providerCallAttempted: false,
        geminiAuthority: false,
        safeReason:
          'server_project_resolver_missing',
      });
    }

    const validatedUserProjectId =
      await effectiveResolveValidatedUserProjectId({
        accessToken:
          tokenSet.accessToken,
        medCasesUid:
          authenticatedUid,
      });

    const persistence =
      await persistOAuthGrant({
        medCasesUid:
          authenticatedUid,
        validatedUserProjectId,
        refreshToken:
          tokenSet.refreshToken,
        accessToken:
          tokenSet.accessToken,
        grantedScopes:
          tokenSet.scope
            ? tokenSet.scope.split(/\s+/)
            : [],
        encryptRefreshToken:
          effectiveEncryptRefreshToken,
        storeEncryptedGrant:
          effectiveStoreEncryptedGrant,
      });

    return writeJson(res, 503, {
      version: VERSION,
      enabled: true,
      inert: true,
      accepted: false,

      authenticated: true,
      uidMatches: true,
      codePresent: true,
      noncePresent: true,

      authorizationCodeReturned: false,
      authorizationCodePersisted: false,
      authorizationCodeLogged: false,

      tokenExchangeAttempted: true,
      accessTokenReturned: false,
      refreshTokenReturned: false,

      tokenPersisted:
        persistence.persisted === true,

      refreshTokenPlaintextPersisted:
        false,

      accessTokenPersisted:
        false,

      projectBindingPersisted:
        persistence.persisted === true,

      providerCallAttempted: false,
      geminiAuthority: false,

      safeReason:
        'oauth_grant_vault_ready_runtime_still_disabled',
    });
  };
}

module.exports = {
  VERSION,
  TOKEN_EXCHANGE_ENABLED,
  TOKEN_PERSISTENCE_ENABLED,
  RUNTIME_ADAPTER_WIRING_ENABLED,
  FLOW_GUARD_ENFORCEMENT_ENABLED,
  CLIENT_SECRET_ENV,
  createStudyGoogleAiOAuthExchangeEndpointInert,
};

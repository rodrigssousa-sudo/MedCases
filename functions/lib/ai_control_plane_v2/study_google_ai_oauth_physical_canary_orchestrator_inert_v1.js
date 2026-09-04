'use strict';

const VERSION =
  'medcases.study.oauth.physical-canary-orchestrator.inert.v1';

const PHYSICAL_CANARY_ENABLED = false;

function cleanString(value) {
  return typeof value === 'string'
    ? value.trim()
    : '';
}

function requireFn(value, label) {
  if (typeof value !== 'function') {
    throw new TypeError(`${label}_REQUIRED`);
  }
  return value;
}

function safeProject(project) {
  if (!project || typeof project !== 'object') {
    return null;
  }

  const projectId = cleanString(project.projectId);
  if (!projectId) {
    return null;
  }

  return Object.freeze({
    projectId,
    displayName:
      cleanString(project.displayName) || null,
  });
}

function safeProjects(projects) {
  return Object.freeze(
    (Array.isArray(projects) ? projects : [])
      .map(safeProject)
      .filter(Boolean)
  );
}

function safeResult(extra) {
  return Object.freeze({
    version: VERSION,
    physicalCanaryEnabled: true,
    accessTokenReturned: false,
    refreshTokenReturned: false,
    authorizationCodeReturned: false,
    accessTokenPersisted: false,
    refreshTokenPlaintextPersisted: false,
    authorizationCodePersisted: false,
    ...extra,
  });
}

function createStudyGoogleAiOAuthPhysicalCanaryOrchestratorInertV1({
  physicalCanaryEnabled = PHYSICAL_CANARY_ENABLED,
  consumeOAuthFlowChallenge,
  exchangeAuthorizationCode,
  discoverProjects,
  validateProject,
  persistEncryptedGrant,
} = {}) {
  if (!physicalCanaryEnabled) {
    return async function disabledPhysicalCanary() {
      return Object.freeze({
        version: VERSION,
        physicalCanaryEnabled: false,
        inert: true,
        accepted: false,
        flowGuardConsumed: false,
        tokenExchangeAttempted: false,
        projectDiscoveryAttempted: false,
        projectValidationAttempted: false,
        tokenPersistenceAttempted: false,
        geminiModelsProbeAttempted: false,
        accessTokenReturned: false,
        refreshTokenReturned: false,
        authorizationCodeReturned: false,
        accessTokenPersisted: false,
        refreshTokenPlaintextPersisted: false,
        authorizationCodePersisted: false,
        safeReason: 'physical_canary_disabled',
      });
    };
  }

  const consume = requireFn(
    consumeOAuthFlowChallenge,
    'FLOW_GUARD_CONSUMER'
  );
  const exchange = requireFn(
    exchangeAuthorizationCode,
    'TOKEN_EXCHANGE'
  );
  const discover = requireFn(
    discoverProjects,
    'PROJECT_DISCOVERY'
  );
  const validate = requireFn(
    validateProject,
    'PROJECT_VALIDATION'
  );
  const persist = requireFn(
    persistEncryptedGrant,
    'ENCRYPTED_GRANT_PERSISTENCE'
  );

  return async function runOneTimePhysicalCanary({
    medcasesUid,
    challengeId,
    state,
    nonce,
    serverAuthorizationCode,
    requestedProjectId = '',
  } = {}) {
    const uid = cleanString(medcasesUid);
    const challenge = cleanString(challengeId);
    const csrfState = cleanString(state);
    const oneTimeNonce = cleanString(nonce);
    const authCode = cleanString(serverAuthorizationCode);
    const projectHint = cleanString(requestedProjectId);

    if (!uid || !challenge || !csrfState || !oneTimeNonce || !authCode) {
      throw new Error('PHYSICAL_CANARY_INPUT_INCOMPLETE');
    }

    // One-time replay/CSRF gate MUST be consumed before token exchange.
    const consumed = await consume({
      medcasesUid: uid,
      challengeId: challenge,
      state: csrfState,
      nonce: oneTimeNonce,
      authCode,
    });

    if (!consumed || consumed.consumed !== true) {
      throw new Error('FLOW_GUARD_NOT_CONSUMED');
    }

    const tokenSet = await exchange({
      serverAuthorizationCode: authCode,
      redirectUri: '',
    });

    const accessToken =
      cleanString(tokenSet && tokenSet.accessToken);
    const refreshToken =
      cleanString(tokenSet && tokenSet.refreshToken);
    const grantedScopes =
      cleanString(tokenSet && tokenSet.scope)
        .split(/\s+/)
        .filter(Boolean);

    if (!accessToken) {
      throw new Error('PHYSICAL_CANARY_ACCESS_TOKEN_MISSING');
    }

    // First physical grant must prove refresh-token issuance before any vault write.
    if (!refreshToken) {
      return safeResult({
        inert: false,
        accepted: false,
        flowGuardConsumed: true,
        tokenExchangeAttempted: true,
        refreshTokenObservedTransiently: false,
        projectDiscoveryAttempted: false,
        projectValidationAttempted: false,
        tokenPersistenceAttempted: false,
        geminiModelsProbeAttempted: false,
        safeReason: 'first_grant_refresh_token_missing',
      });
    }

    const discovered =
      safeProjects(
        await discover({
          accessToken,
        })
      );

    if (discovered.length === 0) {
      return safeResult({
        inert: false,
        accepted: false,
        flowGuardConsumed: true,
        tokenExchangeAttempted: true,
        refreshTokenObservedTransiently: true,
        projectDiscoveryAttempted: true,
        projectValidationAttempted: false,
        tokenPersistenceAttempted: false,
        geminiModelsProbeAttempted: false,
        discoveredProjects: [],
        safeReason: 'no_active_google_cloud_project_discovered',
      });
    }

    let selectedProjectId = projectHint;

    if (!selectedProjectId) {
      if (discovered.length !== 1) {
        return safeResult({
          inert: false,
          accepted: false,
          flowGuardConsumed: true,
          tokenExchangeAttempted: true,
          refreshTokenObservedTransiently: true,
          projectDiscoveryAttempted: true,
          projectValidationAttempted: false,
          tokenPersistenceAttempted: false,
          geminiModelsProbeAttempted: false,
          discoveredProjects: discovered,
          safeReason: 'server_discovered_multiple_projects_selection_required',
        });
      }
      selectedProjectId = discovered[0].projectId;
    }

    if (!discovered.some((p) => p.projectId === selectedProjectId)) {
      return safeResult({
        inert: false,
        accepted: false,
        flowGuardConsumed: true,
        tokenExchangeAttempted: true,
        refreshTokenObservedTransiently: true,
        projectDiscoveryAttempted: true,
        projectValidationAttempted: false,
        tokenPersistenceAttempted: false,
        geminiModelsProbeAttempted: false,
        discoveredProjects: discovered,
        safeReason: 'requested_project_not_server_discovered',
      });
    }

    // The client project ID is only a hint. Server validation remains authoritative.
    const validatedProject = await validate({
      accessToken,
      requestedProjectId: selectedProjectId,
    });

    if (
      !validatedProject ||
      validatedProject.serverValidated !== true ||
      cleanString(validatedProject.projectId) !== selectedProjectId ||
      validatedProject.geminiApiEnabled !== true ||
      validatedProject.serviceUsageUse !== true
    ) {
      throw new Error('SERVER_PROJECT_VALIDATION_FAILED');
    }

    // validateProject is required to include the Gemini /v1/models quota-project probe.
    const persistence = await persist({
      medCasesUid: uid,
      validatedUserProjectId: selectedProjectId,
      refreshToken,
      accessToken,
      grantedScopes,
    });

    if (
      !persistence ||
      persistence.persisted !== true ||
      persistence.refreshTokenPlaintextPersisted !== false ||
      persistence.accessTokenPersisted !== false
    ) {
      throw new Error('ENCRYPTED_VAULT_PERSISTENCE_FAILED');
    }

    return safeResult({
      inert: false,
      accepted: true,
      flowGuardConsumed: true,
      tokenExchangeAttempted: true,
      refreshTokenObservedTransiently: true,
      projectDiscoveryAttempted: true,
      projectValidationAttempted: true,
      tokenPersistenceAttempted: true,
      encryptedRefreshTokenPersisted: true,
      geminiModelsProbeAttempted: true,
      geminiModelsProbePassed: true,
      validatedProjectId: selectedProjectId,
      serviceUsageUse: true,
      geminiApiEnabled: true,
      safeReason: 'physical_canary_ready_path_completed',
    });
  };
}

module.exports = {
  VERSION,
  PHYSICAL_CANARY_ENABLED,
  createStudyGoogleAiOAuthPhysicalCanaryOrchestratorInertV1,
};

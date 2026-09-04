'use strict';

function cleanString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function requireFn(value, label) {
  if (typeof value !== 'function') {
    throw new TypeError(`${label}_REQUIRED`);
  }
  return value;
}

function safeProject(project) {
  if (!project || typeof project !== 'object') return null;
  const projectId = cleanString(project.projectId);
  if (!projectId) return null;
  return Object.freeze({
    projectId,
    projectNumber: cleanString(project.projectNumber) || null,
    displayName: cleanString(project.displayName) || null,
  });
}

function safeProjects(projects) {
  const seen = new Set();
  const out = [];
  for (const value of Array.isArray(projects) ? projects : []) {
    const project = safeProject(value);
    if (!project || seen.has(project.projectId)) continue;
    seen.add(project.projectId);
    out.push(project);
  }
  return Object.freeze(out);
}

function safeResult(extra) {
  return Object.freeze({
    inert: false,
    accepted: false,
    accessTokenReturned: false,
    refreshTokenReturned: false,
    authorizationCodeReturned: false,
    accessTokenPersisted: false,
    refreshTokenPlaintextPersisted: false,
    authorizationCodePersisted: false,
    ...extra,
  });
}

function createStudyGoogleAiOAuthTwoPhasePhysicalCanaryOrchestratorV1({
  consumeOAuthFlowChallenge,
  exchangeAuthorizationCode,
  discoverProjects,
  validateProject,
  persistEncryptedGrant,
  createPendingGrant,
  consumePendingGrant,
  refreshAccessToken,
}) {
  const consumeFlow = requireFn(
    consumeOAuthFlowChallenge,
    'FLOW_GUARD_CONSUMER',
  );
  const exchange = requireFn(
    exchangeAuthorizationCode,
    'TOKEN_EXCHANGE',
  );
  const discover = requireFn(
    discoverProjects,
    'PROJECT_DISCOVERY',
  );
  const validate = requireFn(
    validateProject,
    'PROJECT_VALIDATION',
  );
  const persist = requireFn(
    persistEncryptedGrant,
    'ENCRYPTED_GRANT_PERSISTENCE',
  );
  const createPending = requireFn(
    createPendingGrant,
    'PENDING_GRANT_CREATOR',
  );
  const consumePending = requireFn(
    consumePendingGrant,
    'PENDING_GRANT_CONSUMER',
  );
  const refreshAccess = requireFn(
    refreshAccessToken,
    'REFRESH_ACCESS_TOKEN',
  );

  async function finalizeGrant({
    uid,
    selectedProjectId,
    refreshToken,
    accessToken,
    grantedScopes,
    pendingSelectionConsumed,
  }) {
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
      persistence.encrypted !== true
    ) {
      throw new Error('ENCRYPTED_VAULT_PERSISTENCE_FAILED');
    }

    return safeResult({
      accepted: true,
      flowGuardConsumed: pendingSelectionConsumed !== true,
      tokenExchangeAttempted: pendingSelectionConsumed !== true,
      refreshTokenObservedTransiently: true,
      projectDiscoveryAttempted: pendingSelectionConsumed !== true,
      projectValidationAttempted: true,
      tokenPersistenceAttempted: true,
      pendingGrantCreated: false,
      pendingSelectionConsumed: pendingSelectionConsumed === true,
      geminiModelsProbeAttempted: true,
      validatedProject: safeProject(validatedProject),
      safeReason: 'physical_canary_ready_path_completed',
    });
  }

  return async function runTwoPhasePhysicalCanary({
    medcasesUid,
    challengeId = '',
    state = '',
    nonce = '',
    serverAuthorizationCode = '',
    requestedProjectId = '',
    selectionId = '',
  }) {
    const uid = cleanString(medcasesUid);
    const selected = cleanString(requestedProjectId);
    const opaqueSelection = cleanString(selectionId);

    if (!uid) {
      throw new Error('MEDCASES_UID_REQUIRED');
    }

    // Phase 2: project selection continuation. No second authorization code.
    if (opaqueSelection) {
      if (!selected) {
        throw new Error('SELECTED_PROJECT_ID_REQUIRED');
      }
      if (
        cleanString(challengeId) ||
        cleanString(state) ||
        cleanString(nonce) ||
        cleanString(serverAuthorizationCode)
      ) {
        throw new Error('PHASE2_MUST_NOT_INCLUDE_AUTHORIZATION_CODE_FLOW_FIELDS');
      }

      let pending = null;
      let finalPersistenceCompleted = false;
      try {
        pending = await consumePending({
          medcasesUid: uid,
          selectionId: opaqueSelection,
          selectedProjectId: selected,
        });

        const refreshToken = cleanString(pending && pending.refreshToken);
        if (!refreshToken) {
          throw new Error('PENDING_REFRESH_TOKEN_MISSING');
        }

        const refreshed = await refreshAccess({ refreshToken });
        const accessToken = cleanString(refreshed && refreshed.accessToken);
        if (!accessToken) {
          throw new Error('PHASE2_REFRESHED_ACCESS_TOKEN_MISSING');
        }

        const result = await finalizeGrant({
          uid,
          selectedProjectId: selected,
          refreshToken,
          accessToken,
          grantedScopes:
            Array.isArray(pending.grantedScopes)
              ? pending.grantedScopes
              : [],
          pendingSelectionConsumed: true,
        });
        finalPersistenceCompleted = true;

        if (pending.pendingLifecycleHardened === true) {
          if (typeof pending.completePendingGrant !== 'function') {
            throw new Error('PENDING_GRANT_COMPLETE_CALLBACK_MISSING');
          }
          const completion = await pending.completePendingGrant();
          if (!completion || completion.consumed !== true) {
            throw new Error('PENDING_GRANT_FINAL_CONSUME_FAILED');
          }
        }

        return result;
      } catch (error) {
        if (
          finalPersistenceCompleted !== true &&
          pending &&
          pending.pendingLifecycleHardened === true &&
          typeof pending.releasePendingGrantClaim === 'function'
        ) {
          try {
            await pending.releasePendingGrantClaim();
          } catch (_) {
            // Do not hide the original failure; bounded claim lease enables recovery.
          }
        }
        throw error;
      }
    }
    // Phase 1: one-time server auth code flow.
    const challenge = cleanString(challengeId);
    const csrfState = cleanString(state);
    const oneTimeNonce = cleanString(nonce);
    const authCode = cleanString(serverAuthorizationCode);

    if (!challenge || !csrfState || !oneTimeNonce || !authCode) {
      throw new Error('PHASE1_AUTHORIZATION_FLOW_FIELDS_REQUIRED');
    }

    const consumed = await consumeFlow({
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

    const accessToken = cleanString(tokenSet && tokenSet.accessToken);
    const refreshToken = cleanString(tokenSet && tokenSet.refreshToken);
    const grantedScopes =
      cleanString(tokenSet && tokenSet.scope)
        .split(/\s+/)
        .filter(Boolean);

    if (!accessToken) {
      throw new Error('PHYSICAL_CANARY_ACCESS_TOKEN_MISSING');
    }
    if (!refreshToken) {
      return safeResult({
        flowGuardConsumed: true,
        tokenExchangeAttempted: true,
        refreshTokenObservedTransiently: false,
        projectDiscoveryAttempted: false,
        projectValidationAttempted: false,
        tokenPersistenceAttempted: false,
        pendingGrantCreated: false,
        pendingSelectionConsumed: false,
        geminiModelsProbeAttempted: false,
        safeReason: 'first_grant_refresh_token_missing',
      });
    }

    const discovered = safeProjects(
      await discover({ accessToken }),
    );

    if (discovered.length === 0) {
      return safeResult({
        flowGuardConsumed: true,
        tokenExchangeAttempted: true,
        refreshTokenObservedTransiently: true,
        projectDiscoveryAttempted: true,
        projectValidationAttempted: false,
        tokenPersistenceAttempted: false,
        pendingGrantCreated: false,
        pendingSelectionConsumed: false,
        geminiModelsProbeAttempted: false,
        discoveredProjects: [],
        safeReason: 'no_active_google_cloud_project_discovered',
      });
    }

    let selectedProjectId = selected;

    if (!selectedProjectId && discovered.length > 1) {
      const pending = await createPending({
        medcasesUid: uid,
        refreshToken,
        discoveredProjects: discovered,
        grantedScopes,
      });

      const returnedSelectionId = cleanString(
        pending && pending.selectionId,
      );
      if (!returnedSelectionId) {
        throw new Error('PENDING_SELECTION_ID_MISSING');
      }

      return safeResult({
        flowGuardConsumed: true,
        tokenExchangeAttempted: true,
        refreshTokenObservedTransiently: true,
        projectDiscoveryAttempted: true,
        projectValidationAttempted: false,
        tokenPersistenceAttempted: false,
        pendingGrantCreated: true,
        pendingSelectionConsumed: false,
        pendingEncryptedRefreshTokenPersisted: true,
        geminiModelsProbeAttempted: false,
        selectionRequired: true,
        selectionId: returnedSelectionId,
        selectionExpiresAtMs:
          Number.isFinite(Number(pending.expiresAtMs))
            ? Number(pending.expiresAtMs)
            : null,
        discoveredProjects: safeProjects(
          pending.discoveredProjects || discovered,
        ),
        safeReason:
          'server_discovered_multiple_projects_pending_selection',
      });
    }

    if (!selectedProjectId) {
      selectedProjectId = discovered[0].projectId;
    }

    if (!discovered.some((p) => p.projectId === selectedProjectId)) {
      return safeResult({
        flowGuardConsumed: true,
        tokenExchangeAttempted: true,
        refreshTokenObservedTransiently: true,
        projectDiscoveryAttempted: true,
        projectValidationAttempted: false,
        tokenPersistenceAttempted: false,
        pendingGrantCreated: false,
        pendingSelectionConsumed: false,
        geminiModelsProbeAttempted: false,
        discoveredProjects: discovered,
        safeReason: 'requested_project_not_server_discovered',
      });
    }

    return finalizeGrant({
      uid,
      selectedProjectId,
      refreshToken,
      accessToken,
      grantedScopes,
      pendingSelectionConsumed: false,
    });
  };
}

module.exports = {
  createStudyGoogleAiOAuthTwoPhasePhysicalCanaryOrchestratorV1,
  safeProject,
  safeProjects,
  safeResult,
};

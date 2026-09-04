'use strict';

/**
 * MedCases AI Control Plane V2 — Plantão live authority v1.
 *
 * This module is the ONLY new owner of live response authority.
 * Existing provider executors remain shadow-safe and keep their internal
 * userResponseAuthority/liveModelSelectionAuthority flags false.
 *
 * Fail-closed rules:
 * - requires server-refreshed V2 execution gate already open;
 * - requires config.enabled + legacyParityMode=false;
 * - requires featureFlags.plantao_router_v2=true;
 * - requires plantao.enabled=true;
 * - requires routerMayRespondToUser=false;
 * - requires rollout enabled and percent > 0;
 * - never accepts client provider/model/authority decisions;
 * - Nano classifies only and can never become the final response;
 * - Gemini is reachable only after Luna technical failure;
 * - Terra is reachable only after Luna success + server clinical policy +
 *   stabilization/cost authorization;
 * - Terra technical failure falls back to the already-valid Luna result,
 *   never to Gemini;
 * - if no safe V2 final response is available, handled=false so index
 *   falls back to the existing legacy live path.
 */

const {
  runGpt5NanoPlantaoRouterRealShadow,
} = require(
  './gpt5_nano_plantao_router_real_shadow_v1'
);

const {
  runGpt56LunaPlantaoPrimaryShadow,
} = require(
  './gpt56_luna_plantao_primary_shadow_v1'
);

const {
  runGemini31FlashLitePaidCrossProviderShadow,
} = require(
  './gemini31_flash_lite_paid_cross_provider_shadow_v1'
);

const {
  runGpt56TerraPlantaoComplexEscalationShadow,
} = require(
  './gpt56_terra_plantao_complex_escalation_shadow_v1'
);

const {
  buildServerContextMetricsV1,
  buildTerraClinicalEscalationDecisionV1,
} = require(
  './terra_clinical_escalation_policy_v1'
);

const {
  buildTerraStabilizedAuthorizationV1,
} = require(
  './terra_escalation_stabilization_v1'
);

const LIVE_AUTHORITY_VERSION =
  'medcases_plantao_live_authority_v1';

const ROLE_ALIAS = Object.freeze({
  luna: 'plantao_primary',
  gemini: 'plantao_cross_provider',
  terra: 'plantao_complex',
});

function _isPlainObject(value) {
  return !!(
    value &&
    typeof value === 'object' &&
    !Array.isArray(value)
  );
}

function _normalizedMode(mode) {
  return typeof mode === 'string'
    ? mode.trim().toLowerCase()
    : '';
}

function _rolloutPercent(config) {
  const value =
    config &&
    _isPlainObject(config.rollout)
      ? Number(config.rollout.percent)
      : 0;

  if (!Number.isFinite(value)) {
    return 0;
  }

  return Math.max(0, Math.min(100, value));
}

function resolvePlantaoLiveAuthorityGateV1({
  config = null,
  mode = 'plantao',
  executionGateOpen = false,
} = {}) {
  if (executionGateOpen !== true) {
    return Object.freeze({
      eligible: false,
      reason: 'execution_gate_closed',
    });
  }

  if (
    !['plantao', 'plantão'].includes(
      _normalizedMode(mode)
    )
  ) {
    return Object.freeze({
      eligible: false,
      reason: 'plantao_only',
    });
  }

  if (
    !_isPlainObject(config) ||
    config.enabled !== true ||
    config.legacyParityMode !== false
  ) {
    return Object.freeze({
      eligible: false,
      reason: 'v2_config_not_live_eligible',
    });
  }

  const flags =
    _isPlainObject(config.featureFlags)
      ? config.featureFlags
      : {};

  if (flags.plantao_router_v2 !== true) {
    return Object.freeze({
      eligible: false,
      reason: 'plantao_router_v2_closed',
    });
  }

  const plantao =
    _isPlainObject(config.plantao)
      ? config.plantao
      : null;

  if (!plantao || plantao.enabled !== true) {
    return Object.freeze({
      eligible: false,
      reason: 'plantao_mode_closed',
    });
  }

  if (plantao.routerMayRespondToUser !== false) {
    return Object.freeze({
      eligible: false,
      reason: 'nano_router_response_contract_invalid',
    });
  }

  if (
    !_isPlainObject(config.rollout) ||
    config.rollout.enabled !== true ||
    _rolloutPercent(config) <= 0
  ) {
    return Object.freeze({
      eligible: false,
      reason: 'rollout_closed',
    });
  }

  return Object.freeze({
    eligible: true,
    reason: 'open',
  });
}

function _providerRemote(
  config,
  key
) {
  const providers =
    config &&
    _isPlainObject(config.shadowProviderCalls)
      ? config.shadowProviderCalls
      : {};

  return _isPlainObject(providers[key])
    ? providers[key]
    : {};
}

function buildPlantaoLiveProviderExecutionConfigV1(
  config
) {
  if (!_isPlainObject(config)) {
    return null;
  }

  const flags =
    _isPlainObject(config.featureFlags)
      ? config.featureFlags
      : {};

  const providers =
    _isPlainObject(config.shadowProviderCalls)
      ? config.shadowProviderCalls
      : {};

  return {
    ...config,
    featureFlags: {
      ...flags,
      gpt5_nano_real_shadow_v1: true,
      gpt56_luna_real_shadow_v1: true,
      gemini31_paid_real_shadow_v1: true,
      gpt56_terra_real_shadow_v1: true,
    },
    shadowProviderCalls: {
      ...providers,
      gpt5Nano: {
        ..._providerRemote(config, 'gpt5Nano'),
        enabled: true,
        rolloutPercent: 100,
      },
      gpt56Luna: {
        ..._providerRemote(config, 'gpt56Luna'),
        enabled: true,
        rolloutPercent: 100,
      },
      gemini31Paid: {
        ..._providerRemote(config, 'gemini31Paid'),
        enabled: true,
        rolloutPercent: 100,
      },
      gpt56Terra: {
        ..._providerRemote(config, 'gpt56Terra'),
        enabled: true,
        rolloutPercent: 100,
      },
    },
  };
}

function _array(value) {
  return Array.isArray(value)
    ? value
    : [];
}

function _lineList(values) {
  return _array(values)
    .filter(
      (value) =>
        typeof value === 'string' &&
        value.trim().length > 0
    )
    .map((value) => '- ' + value.trim());
}

function _differentialLines(value) {
  return _array(value)
    .map((item) => {
      if (
        typeof item === 'string' &&
        item.trim().length > 0
      ) {
        return '- ' + item.trim();
      }

      if (!_isPlainObject(item)) {
        return null;
      }

      const diagnosis =
        typeof item.diagnosis === 'string'
          ? item.diagnosis.trim()
          : '';

      if (!diagnosis) {
        return null;
      }

      const rationale =
        typeof item.rationale === 'string' &&
        item.rationale.trim().length > 0
          ? ' — ' + item.rationale.trim()
          : '';

      const urgency =
        typeof item.urgency === 'string' &&
        item.urgency.trim().length > 0
          ? ' [' + item.urgency.trim() + ']'
          : '';

      return '- ' + diagnosis + rationale + urgency;
    })
    .filter(Boolean);
}

function renderPlantaoClinicalResultV1(
  result,
  {
    lang = 'pt',
  } = {}
) {
  if (!_isPlainObject(result)) {
    return '';
  }

  const es =
    typeof lang === 'string' &&
    lang.trim().toLowerCase().startsWith('es');

  const labels = es
    ? {
        summary: 'Resumen clínico',
        conflicts: 'Conflictos diagnósticos',
        differential: 'Diagnóstico diferencial',
        actions: 'Acciones críticas',
        disposition: 'Conducta / destino',
        safety: 'Alertas de seguridad',
        uncertainties: 'Incertidumbres',
        confidence: 'Confianza',
        more:
          'Se necesita información clínica adicional.',
      }
    : {
        summary: 'Resumo clínico',
        conflicts: 'Conflitos diagnósticos',
        differential: 'Diagnóstico diferencial',
        actions: 'Ações críticas',
        disposition: 'Conduta / destino',
        safety: 'Alertas de segurança',
        uncertainties: 'Incertezas',
        confidence: 'Confiança',
        more:
          'São necessárias informações clínicas adicionais.',
      };

  const blocks = [];

  const summary =
    typeof result.clinical_summary === 'string'
      ? result.clinical_summary.trim()
      : (
          typeof result.clinical_synthesis === 'string'
            ? result.clinical_synthesis.trim()
            : ''
        );

  if (summary) {
    blocks.push(
      labels.summary + '\n' + summary
    );
  }

  const conflicts =
    _lineList(result.diagnostic_conflicts);

  if (conflicts.length > 0) {
    blocks.push(
      labels.conflicts + '\n' +
      conflicts.join('\n')
    );
  }

  const differential =
    _differentialLines(result.differential);

  if (differential.length > 0) {
    blocks.push(
      labels.differential + '\n' +
      differential.join('\n')
    );
  }

  const actions =
    _lineList(result.critical_actions);

  if (actions.length > 0) {
    blocks.push(
      labels.actions + '\n' +
      actions.join('\n')
    );
  }

  const disposition =
    _lineList(result.disposition);

  if (disposition.length > 0) {
    blocks.push(
      labels.disposition + '\n' +
      disposition.join('\n')
    );
  }

  const safety =
    _lineList(result.safety_flags);

  if (safety.length > 0) {
    blocks.push(
      labels.safety + '\n' +
      safety.join('\n')
    );
  }

  const uncertainties =
    _lineList(result.uncertainties);

  if (uncertainties.length > 0) {
    blocks.push(
      labels.uncertainties + '\n' +
      uncertainties.join('\n')
    );
  }

  if (
    typeof result.confidence === 'string' &&
    result.confidence.trim().length > 0
  ) {
    blocks.push(
      labels.confidence + ': ' +
      result.confidence.trim()
    );
  }

  if (result.needs_more_information === true) {
    blocks.push(labels.more);
  }

  return blocks.join('\n\n').trim();
}

function _isCompletedClinicalResult(result) {
  return !!(
    _isPlainObject(result) &&
    result.attempted === true &&
    result.completed === true &&
    result.responseValid === true &&
    _isPlainObject(result.parsedClinicalResult)
  );
}

function _tokenTotals(results) {
  let input = 0;
  let output = 0;

  for (const result of results) {
    if (!_isPlainObject(result)) {
      continue;
    }

    if (
      Number.isInteger(result.inputTokens) &&
      result.inputTokens >= 0
    ) {
      input += result.inputTokens;
    }

    if (
      Number.isInteger(result.outputTokens) &&
      result.outputTokens >= 0
    ) {
      output += result.outputTokens;
    }
  }

  return Object.freeze({
    input,
    output,
  });
}

function _finalResponse({
  selectedResult,
  selectedAlias,
  lang,
  allResults,
  startedAt,
}) {
  const text =
    renderPlantaoClinicalResultV1(
      selectedResult.parsedClinicalResult,
      { lang }
    );

  if (!text) {
    return null;
  }

  const totals =
    _tokenTotals(allResults);

  return Object.freeze({
    text,
    model: selectedAlias,
    inputTokensApprox: totals.input,
    outputTokensApprox: totals.output,
    durationMs:
      Math.max(
        0,
        Date.now() - startedAt
      ),
  });
}

function _closed(reason) {
  return Object.freeze({
    version: LIVE_AUTHORITY_VERSION,
    eligible: false,
    handled: false,
    suppressShadow: false,
    userResponseAuthority: false,
    liveModelSelectionAuthority: false,
    reason,
  });
}

function _eligibleFailure(
  reason,
  attemptedAliases = []
) {
  return Object.freeze({
    version: LIVE_AUTHORITY_VERSION,
    eligible: true,
    handled: false,
    suppressShadow: true,
    userResponseAuthority: false,
    liveModelSelectionAuthority: false,
    reason,
    attemptedAliases:
      Object.freeze(
        [...attemptedAliases]
      ),
  });
}

function _handled({
  selectedAlias,
  response,
  attemptedAliases,
}) {
  return Object.freeze({
    version: LIVE_AUTHORITY_VERSION,
    eligible: true,
    handled: true,
    suppressShadow: true,
    userResponseAuthority: true,
    liveModelSelectionAuthority: true,
    selectedAlias,
    attemptedAliases:
      Object.freeze(
        [...attemptedAliases]
      ),
    response,
    reason: 'completed',
  });
}

async function executePlantaoLiveAuthorityV1({
  config = null,
  executionGateOpen = false,
  uid = '',
  mode = 'plantao',
  lang = 'pt',
  userMessage = '',
  history = [],
  patientContext = null,
  providerDataPolicy = null,
  protectedClinicalProjection = null,
  openAiApiKey = '',
  geminiApiKey = '',
  runners = null,
  helpers = null,
} = {}) {
  const gate =
    resolvePlantaoLiveAuthorityGateV1({
      config,
      mode,
      executionGateOpen,
    });

  if (!gate.eligible) {
    return _closed(gate.reason);
  }

  const startedAt = Date.now();

  const liveConfig =
    buildPlantaoLiveProviderExecutionConfigV1(
      config
    );

  if (!liveConfig) {
    return _eligibleFailure(
      'live_execution_config_invalid'
    );
  }

  const rr =
    _isPlainObject(runners)
      ? runners
      : {};

  const hh =
    _isPlainObject(helpers)
      ? helpers
      : {};

  const runNano =
    typeof rr.nano === 'function'
      ? rr.nano
      : runGpt5NanoPlantaoRouterRealShadow;

  const runLuna =
    typeof rr.luna === 'function'
      ? rr.luna
      : runGpt56LunaPlantaoPrimaryShadow;

  const runGemini =
    typeof rr.gemini === 'function'
      ? rr.gemini
      : runGemini31FlashLitePaidCrossProviderShadow;

  const runTerra =
    typeof rr.terra === 'function'
      ? rr.terra
      : runGpt56TerraPlantaoComplexEscalationShadow;

  const buildMetrics =
    typeof hh.buildServerContextMetrics === 'function'
      ? hh.buildServerContextMetrics
      : buildServerContextMetricsV1;

  const buildTerraDecision =
    typeof hh.buildTerraDecision === 'function'
      ? hh.buildTerraDecision
      : buildTerraClinicalEscalationDecisionV1;

  const stabilizeTerra =
    typeof hh.stabilizeTerra === 'function'
      ? hh.stabilizeTerra
      : buildTerraStabilizedAuthorizationV1;

  const attemptedAliases = [];
  const results = [];

  const common = {
    config: liveConfig,
    uid,
    mode: 'plantao',
    userMessage,
    history,
    patientContext,
    providerDataPolicy,
    protectedClinicalProjection,
  };

  let nanoResult;

  try {
    attemptedAliases.push('plantao_router');

    nanoResult =
      await runNano({
        ...common,
        openAiApiKey,
      });
    console.info(JSON.stringify({
      event: 'plantao_live_nano_result_v1',
      attempted: nanoResult?.attempted === true,
      completed: nanoResult?.completed === true,
      gateReason: typeof nanoResult?.gateReason === 'string' && /^[A-Za-z0-9_.:-]{1,80}$/.test(nanoResult.gateReason)
        ? nanoResult.gateReason
        : 'unknown',

      failureStage: ['provider_exception','provider_http_reject','provider_response_invalid'].includes(nanoResult?.failureStage)
        ? nanoResult.failureStage
        : null,}));
  } catch (_) {
    return _eligibleFailure(
      'nano_router_exception',
      attemptedAliases
    );
  }

  results.push(nanoResult);

  if (
    !_isPlainObject(nanoResult) ||
    nanoResult.attempted !== true ||
    nanoResult.completed !== true ||
    !_isPlainObject(nanoResult.classification)
  ) {
    return _eligibleFailure(
      'nano_router_unavailable',
      attemptedAliases
    );
  }

  let lunaResult;

  try {
    attemptedAliases.push(ROLE_ALIAS.luna);

    lunaResult =
      await runLuna({
        ...common,
        openAiApiKey,
      });
  } catch (_) {
    return _eligibleFailure(
      'luna_primary_exception',
      attemptedAliases
    );
  }

  results.push(lunaResult);

  if (
    _isPlainObject(lunaResult) &&
    lunaResult.technicalFailure === true
  ) {
    const technicalFallback =
      liveConfig &&
      _isPlainObject(liveConfig.plantao) &&
      _isPlainObject(
        liveConfig.plantao.technicalFallback
      )
        ? liveConfig.plantao.technicalFallback
        : null;

    if (
      !technicalFallback ||
      technicalFallback.enabled !== true
    ) {
      return _eligibleFailure(
        'technical_fallback_disabled',
        attemptedAliases
      );
    }

    let geminiResult;

    try {
      attemptedAliases.push(
        ROLE_ALIAS.gemini
      );

      geminiResult =
        await runGemini({
          ...common,
          upstreamTechnicalFailure: true,
          upstreamFailureClass:
            typeof lunaResult.failureClass ===
              'string'
              ? lunaResult.failureClass
              : null,
          upstreamClinicalEscalation: false,
          geminiApiKey,
        });
    } catch (_) {
      return _eligibleFailure(
        'gemini_technical_fallback_exception',
        attemptedAliases
      );
    }

    results.push(geminiResult);

    if (!_isCompletedClinicalResult(geminiResult)) {
      return _eligibleFailure(
        'gemini_technical_fallback_unavailable',
        attemptedAliases
      );
    }

    const response =
      _finalResponse({
        selectedResult: geminiResult,
        selectedAlias: ROLE_ALIAS.gemini,
        lang,
        allResults: results,
        startedAt,
      });

    if (!response) {
      return _eligibleFailure(
        'gemini_response_normalization_failed',
        attemptedAliases
      );
    }

    return _handled({
      selectedAlias: ROLE_ALIAS.gemini,
      response,
      attemptedAliases,
    });
  }

  if (!_isCompletedClinicalResult(lunaResult)) {
    return _eligibleFailure(
      'luna_primary_unavailable',
      attemptedAliases
    );
  }

  let selectedResult = lunaResult;
  let selectedAlias = ROLE_ALIAS.luna;

  const flags =
    _isPlainObject(liveConfig.featureFlags)
      ? liveConfig.featureFlags
      : {};

  const plantao =
    _isPlainObject(liveConfig.plantao)
      ? liveConfig.plantao
      : {};

  const escalation =
    _isPlainObject(plantao.clinicalEscalation)
      ? plantao.clinicalEscalation
      : {};

  if (
    flags.clinical_escalation_v2 === true &&
    escalation.enabled === true
  ) {
    const serverContextMetrics =
      buildMetrics({
        userMessage,
        history,
        patientContext,
      });

    const policyConfig =
      liveConfig &&
      _isPlainObject(
        liveConfig.clinicalEscalationPolicies
      ) &&
      _isPlainObject(
        liveConfig.clinicalEscalationPolicies.terra
      )
        ? liveConfig
            .clinicalEscalationPolicies
            .terra
        : null;

    const clinicalDecision =
      buildTerraDecision({
        mode: 'plantao',
        lunaResult,
        serverContextMetrics,
        policyConfig,
      });

    const terraProviderConfig =
      _providerRemote(
        liveConfig,
        'gpt56Terra'
      );

    const stabilizationConfig =
      liveConfig &&
      _isPlainObject(
        liveConfig
          .clinicalEscalationStabilization
      ) &&
      _isPlainObject(
        liveConfig
          .clinicalEscalationStabilization
          .terra
      )
        ? liveConfig
            .clinicalEscalationStabilization
            .terra
        : null;

    const stabilized =
      stabilizeTerra({
        clinicalDecision,
        serverContextMetrics,
        terraProviderConfig,
        stabilizationConfig,
      });

    if (
      _isPlainObject(stabilized) &&
      stabilized.providerCallAllowed === true &&
      stabilized.clinicalEscalation === true &&
      stabilized.terraAllowed === true
    ) {
      let terraResult = null;

      try {
        attemptedAliases.push(
          ROLE_ALIAS.terra
        );

        terraResult =
          await runTerra({
            ...common,
            clinicalEscalation: true,
            terraAllowed: true,
            escalationReasons:
              Array.isArray(
                stabilized.signalCodes
              )
                ? stabilized.signalCodes
                : [],
            upstreamTechnicalFailure: false,
            upstreamFailureClass: null,
            openAiApiKey,
          });
      } catch (_) {
        terraResult = null;
      }

      if (terraResult) {
        results.push(terraResult);
      }

      if (_isCompletedClinicalResult(terraResult)) {
        selectedResult = terraResult;
        selectedAlias = ROLE_ALIAS.terra;
      }
    }
  }

  const response =
    _finalResponse({
      selectedResult,
      selectedAlias,
      lang,
      allResults: results,
      startedAt,
    });

  if (!response) {
    return _eligibleFailure(
      'final_response_normalization_failed',
      attemptedAliases
    );
  }

  return _handled({
    selectedAlias,
    response,
    attemptedAliases,
  });
}

module.exports = Object.freeze({
  LIVE_AUTHORITY_VERSION,
  ROLE_ALIAS,
  resolvePlantaoLiveAuthorityGateV1,
  buildPlantaoLiveProviderExecutionConfigV1,
  renderPlantaoClinicalResultV1,
  executePlantaoLiveAuthorityV1,
});

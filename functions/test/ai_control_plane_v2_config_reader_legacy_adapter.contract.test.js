'use strict';

const assert = require('assert');

const {
  makeSafeBootstrapConfig,
} = require('../lib/ai_control_plane_v2/config_defaults');

const {
  POINTER_COLLECTION,
  POINTER_DOCUMENT,
  VERSION_COLLECTION,
  loadV2ConfigFromFirestore,
  resetV2ConfigCacheForTests,
} = require('../lib/ai_control_plane_v2/config_reader');

const {
  adaptLegacyGeminiPaidProxyRequest,
} = require('../lib/ai_control_plane_v2/legacy_request_adapter');

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function fakeFirestore(documents) {
  return {
    collection(collectionName) {
      return {
        doc(documentName) {
          return {
            async get() {
              const key = `${collectionName}/${documentName}`;
              if (!Object.hasOwn(documents, key)) {
                return {
                  exists: false,
                  data() {
                    return undefined;
                  },
                };
              }
              return {
                exists: true,
                data() {
                  return clone(documents[key]);
                },
              };
            },
          };
        },
      };
    },
  };
}

(async () => {
  resetV2ConfigCacheForTests();

  const bootstrap = makeSafeBootstrapConfig();

  assert.strictEqual(POINTER_COLLECTION, 'ai_config');
  assert.strictEqual(POINTER_DOCUMENT, 'current');
  assert.strictEqual(VERSION_COLLECTION, 'ai_config_versions');

  // Missing pointer -> fail closed compiled bootstrap.
  {
    const state = await loadV2ConfigFromFirestore({
      firestore: fakeFirestore({}),
      env: { AI_CONTROL_PLANE_V2_ENABLED: 'true' },
      nowMs: 1000,
    });

    assert.strictEqual(state.source, 'compiled_bootstrap');
    assert.strictEqual(state.executionAllowed, false);
    assert.strictEqual(state.errorCode, 'pointer_missing');
    assert.strictEqual(state.config.enabled, false);
  }

  // Pointer present but version missing -> fail closed.
  {
    const state = await loadV2ConfigFromFirestore({
      firestore: fakeFirestore({
        'ai_config/current': {
          schemaVersion: 'ai-config-v2',
          activeVersion: 'AI_CONFIG_V99',
        },
      }),
      env: { AI_CONTROL_PLANE_V2_ENABLED: 'true' },
      nowMs: 2000,
    });

    assert.strictEqual(state.source, 'compiled_bootstrap');
    assert.strictEqual(state.executionAllowed, false);
    assert.strictEqual(state.errorCode, 'version_missing');
  }

  // Version identity mismatch -> fail closed.
  {
    const remote = clone(bootstrap);
    remote.configVersion = 'AI_CONFIG_WRONG';

    const state = await loadV2ConfigFromFirestore({
      firestore: fakeFirestore({
        'ai_config/current': {
          schemaVersion: 'ai-config-v2',
          activeVersion: 'AI_CONFIG_V12',
        },
        'ai_config_versions/AI_CONFIG_V12': remote,
      }),
      env: { AI_CONTROL_PLANE_V2_ENABLED: 'true' },
      nowMs: 3000,
    });

    assert.strictEqual(state.source, 'compiled_bootstrap');
    assert.strictEqual(state.executionAllowed, false);
    assert.strictEqual(state.errorCode, 'version_identity_mismatch');
  }

  // Valid remote config can be read but local env hard gate keeps execution OFF.
  {
    const remote = clone(bootstrap);
    remote.configVersion = 'AI_CONFIG_V12';
    remote.enabled = true;
    remote.legacyParityMode = false;
    remote.rollout.enabled = true;
    remote.rollout.percent = 10;

    const state = await loadV2ConfigFromFirestore({
      firestore: fakeFirestore({
        'ai_config/current': {
          schemaVersion: 'ai-config-v2',
          activeVersion: 'AI_CONFIG_V12',
        },
        'ai_config_versions/AI_CONFIG_V12': remote,
      }),
      env: { AI_CONTROL_PLANE_V2_ENABLED: 'false' },
      nowMs: 4000,
    });

    assert.strictEqual(state.source, 'firestore_version');
    assert.strictEqual(state.pointerVersion, 'AI_CONFIG_V12');
    assert.strictEqual(state.config.configVersion, 'AI_CONFIG_V12');
    assert.strictEqual(state.executionAllowed, false);
  }

  // Same valid remote config + explicit server env hard gate can allow execution.
  // This proves the gate formula only; nothing is wired into the live endpoint yet.
  {
    const remote = clone(bootstrap);
    remote.configVersion = 'AI_CONFIG_V13';
    remote.enabled = true;
    remote.legacyParityMode = false;
    remote.rollout.enabled = true;
    remote.rollout.percent = 1;

    const state = await loadV2ConfigFromFirestore({
      firestore: fakeFirestore({
        'ai_config/current': {
          schemaVersion: 'ai-config-v2',
          activeVersion: 'AI_CONFIG_V13',
        },
        'ai_config_versions/AI_CONFIG_V13': remote,
      }),
      env: { AI_CONTROL_PLANE_V2_ENABLED: 'true' },
      nowMs: 5000,
    });

    assert.strictEqual(state.source, 'firestore_version');
    assert.strictEqual(state.executionAllowed, true);
  }

  // Legacy Study request -> capability contract.
  {
    const adapted = adaptLegacyGeminiPaidProxyRequest({
      userMessage: 'synthetic study request',
      systemPrompt: 'legacy prompt',
      history: [
        { role: 'user', content: 'previous' },
        { role: 'model', content: 'answer' },
      ],
      mode: 'study',
      lang: 'pt',
      requestId: 'req-1',
      maxOutputTokens: 800,

      // Legacy routing hints must not become V2 authority.
      provider: 'openai',
      model: 'client-model',
      model_tier: 'pro',
      tier: 'cognitive',
      temperature: 0.9,
    });

    assert.strictEqual(adapted.ok, true);
    assert.strictEqual(adapted.request.mode, 'study');
    assert.strictEqual(adapted.request.task, 'clinical_question');
    assert.strictEqual(adapted.request.locale, 'pt-BR');
    assert.strictEqual(
      adapted.metadata.ignoredClientRoutingHints,
      true
    );
    assert.strictEqual(adapted.metadata.clientRoutingAuthority, false);
    assert.strictEqual(Object.hasOwn(adapted.request, 'provider'), false);
    assert.strictEqual(Object.hasOwn(adapted.request, 'model'), false);
    assert.strictEqual(
      Object.hasOwn(adapted.request.input, 'provider'),
      false
    );
    assert.strictEqual(
      Object.hasOwn(adapted.request.input, 'model'),
      false
    );
  }

  // Legacy Plantão request -> clinical_reasoning.
  {
    const adapted = adaptLegacyGeminiPaidProxyRequest({
      userMessage: 'synthetic plantao request',
      mode: 'plantao',
      lang: 'es',
      conversationId: 'conv-1',
      clinicalThreadId: 'thread-1',
      sameTopic: true,
      contextualFollowup: true,
      patientContext: { present: true },
    });

    assert.strictEqual(adapted.ok, true);
    assert.strictEqual(adapted.request.mode, 'plantao');
    assert.strictEqual(adapted.request.task, 'clinical_reasoning');
    assert.strictEqual(adapted.request.locale, 'es');
    assert.strictEqual(adapted.request.conversation_id, 'conv-1');
    assert.strictEqual(adapted.request.clinical_thread_id, 'thread-1');
    assert.strictEqual(adapted.request.same_topic, true);
    assert.strictEqual(adapted.request.contextual_followup, true);
    assert.strictEqual(
      adapted.request.context_flags.patient_context_present,
      true
    );
  }

  // Invalid mode is rejected before any routing.
  {
    const adapted = adaptLegacyGeminiPaidProxyRequest({
      userMessage: 'x',
      mode: 'unknown-mode',
    });
    assert.strictEqual(adapted.ok, false);
    assert.strictEqual(adapted.errorCode, 'unsupported_legacy_mode');
  }

  console.log('AI_CONTROL_PLANE_V2_CONFIG_READER_LEGACY_ADAPTER=PASS');
  console.log('SERVER_ONLY_VERSIONED_POINTER=PASS');
  console.log('CONFIG_VERSION_IDENTITY_GUARD=PASS');
  console.log('MISSING_OR_INVALID_REMOTE_CONFIG_FAILS_CLOSED=PASS');
  console.log('SERVER_ENV_HARD_GATE=PASS');
  console.log('LEGACY_REQUEST_ADAPTER=PASS');
  console.log('LEGACY_PROVIDER_MODEL_HINTS_IGNORED=PASS');
  console.log('OLD_BINARY_COMPATIBILITY_ADAPTER=PASS');
  console.log('LIVE_ENDPOINT_WIRING=NONE');
})().catch((error) => {
  console.error(error);
  process.exit(1);
});

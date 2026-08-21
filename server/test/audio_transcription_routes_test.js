'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const http = require('node:http');
const test = require('node:test');
const express = require('express');

const {
  ATTESTATION_DOMAIN,
  ATTESTATION_SCHEMA,
  GRANT_SCOPE,
  OPENAI_TRANSCRIPTION_ENDPOINT,
  TRANSCRIPTION_MODEL,
  canonicalAttestationPayload,
  registerAudioTranscriptionRoutes,
} = require('../audio_transcription_routes');

function logger() {
  return { info() {}, warn() {}, error() {}, debug() {} };
}

function fixture() {
  const { privateKey, publicKey } = crypto.generateKeyPairSync('ed25519');
  const privatePem = privateKey.export({ type: 'pkcs8', format: 'pem' });
  return {
    env: {
      OPENAI_API_KEY: 'sk-synthetic-server-test-key-not-production',
      MEDCASES_AUDIO_GRANT_SECRET:
        'synthetic_grant_secret_2026_abcdefghijklmnopqrstuvwxyz_0123456789',
      MEDCASES_AUDIO_ATTESTATION_KEY_ID: 'audio-test-key-v1',
      MEDCASES_AUDIO_ATTESTATION_PRIVATE_KEY_PEM: privatePem,
    },
    publicKey,
  };
}

async function withServer({ env, fetchImpl }, action) {
  const app = express();
  const firebaseAuthStub = (req, _res, next) => {
    req.auth = { uid: 'firebase-test-user-001', email: null };
    next();
  };

  const runtimeSurface = registerAudioTranscriptionRoutes({
    app,
    authenticateFirebaseToken: firebaseAuthStub,
    log: logger(),
    isProd: false,
    env,
    fetchImpl,
  });

  // Mirrors production ordering after the macrobuild: specific audio routes
  // are already registered; generic JSON + Firebase protect remaining /api/ai.
  app.use(express.json({ limit: '512kb' }));
  app.use('/api/ai', (_req, res) => {
    res.status(418).json({ error: 'generic_auth_fallback_reached' });
  });

  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  const base = `http://127.0.0.1:${address.port}`;
  try {
    return await action({ base, runtimeSurface });
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

async function grant(base, sessionId = 'session_audio_001', dedupe = 'session_audio_001:segment:0') {
  const response = await fetch(`${base}/api/ai/audio/grant`, {
    method: 'POST',
    headers: {
      Authorization: 'Bearer firebase-synthetic-token',
      'Content-Type': 'application/json',
      'X-Request-ID': 'server-test-grant',
    },
    body: JSON.stringify({
      sessionId,
      deduplicationKey: dedupe,
      scope: GRANT_SCOPE,
    }),
  });
  const json = await response.json();
  return { response, json };
}

function transcriptionForm({
  sessionId = 'session_audio_001',
  dedupe = 'session_audio_001:segment:0',
  bytes = Buffer.from('synthetic-m4a-payload-without-patient-data', 'utf8'),
} = {}) {
  const form = new FormData();
  form.append('sessionId', sessionId);
  form.append('idempotencyKey', dedupe);
  form.append('model', TRANSCRIPTION_MODEL);
  form.append('language', 'pt');
  form.append('prompt', 'Transcrição médica. Preservar doses, números e unidades.');
  form.append('keywordsJson', JSON.stringify(['ceftriaxona', 'creatinina']));
  form.append('contentType', 'audio/mp4');
  form.append('contentLengthBytes', String(bytes.length));
  form.append('audio', new Blob([bytes], { type: 'audio/mp4' }), 'segment_00000.m4a');
  return form;
}

function verifyAttestationSignature(json, publicKey) {
  const attestation = json.noRetentionAttestation;
  assert.equal(attestation.schemaVersion, ATTESTATION_SCHEMA);
  assert.equal(attestation.temporaryAudioDeleted, true);
  assert.equal(attestation.persistedAudioBytes, 0);
  assert.equal(attestation.sensitivePayloadLogged, false);

  const parts = attestation.attestationToken.split('.');
  assert.equal(parts.length, 3);
  assert.equal(parts[0], 'ed25519');
  assert.equal(parts[1], 'audio-test-key-v1');

  const canonical = canonicalAttestationPayload(attestation, parts[1]);
  assert.equal(canonical.split('\n')[0], ATTESTATION_DOMAIN);
  const valid = crypto.verify(
    null,
    Buffer.from(canonical, 'utf8'),
    publicKey,
    Buffer.from(parts[2], 'base64url'),
  );
  assert.equal(valid, true);
}

test('production-capable routes fail closed when audio secrets are absent', async () => {
  await withServer(
    { env: {}, fetchImpl: async () => { throw new Error('must not call'); } },
    async ({ base, runtimeSurface }) => {
      assert.equal(runtimeSurface.ready, false);
      const result = await grant(base);
      assert.equal(result.response.status, 503);
      assert.equal(result.json.error, 'audio_backend_not_configured');
    },
  );
});

test('grant is Firebase-authenticated shape and returns bound ephemeral MedCases token', async () => {
  const f = fixture();
  await withServer(
    {
      env: f.env,
      fetchImpl: async () => { throw new Error('grant must not call OpenAI'); },
    },
    async ({ base, runtimeSurface }) => {
      assert.equal(runtimeSurface.ready, true);
      assert.equal(runtimeSurface.productionCallsiteWired, false);
      assert.equal(runtimeSurface.productionCutoverEnabled, false);
      const result = await grant(base);
      assert.equal(result.response.status, 200);
      assert.equal(result.json.sessionId, 'session_audio_001');
      assert.equal(result.json.deduplicationKey, 'session_audio_001:segment:0');
      assert.equal(result.json.scope, GRANT_SCOPE);
      assert.match(result.json.accessToken, /^mcg1\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/);
      assert.ok(Date.parse(result.json.issuedAtUtc));
      assert.ok(Date.parse(result.json.expiresAtUtc));
    },
  );
});

test('multipart M4A reaches injected OpenAI fetch and returns signed zero-durable-audio contract', async () => {
  const f = fixture();
  let openAiCalls = 0;
  let observedModel = null;
  let observedLanguage = null;
  let observedAudioSize = null;
  let observedPrompt = null;

  const fakeOpenAiFetch = async (url, options) => {
    openAiCalls += 1;
    assert.equal(url, OPENAI_TRANSCRIPTION_ENDPOINT);
    assert.equal(options.method, 'POST');
    assert.match(options.headers.Authorization, /^Bearer sk-synthetic-/);
    assert.ok(options.body instanceof FormData);
    observedModel = options.body.get('model');
    observedLanguage = options.body.get('language');
    observedPrompt = options.body.get('prompt');
    const file = options.body.get('file');
    observedAudioSize = file.size;
    return new Response(
      JSON.stringify({ text: 'Ceftriaxona 2 g intravenosa.' }),
      { status: 200, headers: { 'content-type': 'application/json' } },
    );
  };

  await withServer(
    { env: f.env, fetchImpl: fakeOpenAiFetch },
    async ({ base }) => {
      const g = await grant(base);
      assert.equal(g.response.status, 200);

      const form = transcriptionForm();
      const response = await fetch(`${base}/api/ai/audio/transcriptions`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${g.json.accessToken}`,
          'X-MedCases-Idempotency-Key': 'session_audio_001:segment:0',
          'X-MedCases-Audio-Retention': 'transient-delete',
          'X-Request-ID': 'server-test-transcribe',
        },
        body: form,
      });
      const json = await response.json();

      assert.equal(response.status, 200);
      assert.equal(openAiCalls, 1);
      assert.equal(observedModel, TRANSCRIPTION_MODEL);
      assert.equal(observedLanguage, 'pt');
      assert.ok(observedAudioSize > 0);
      assert.match(observedPrompt, /ceftriaxona/);
      assert.equal(json.idempotencyKey, 'session_audio_001:segment:0');
      assert.equal(json.transcript, 'Ceftriaxona 2 g intravenosa.');
      assert.match(json.resultRef, /^backend:\/\/audio\/[a-f0-9]{32}$/);
      verifyAttestationSignature(json, f.publicKey);
    },
  );
});

test('grant cannot be replayed against a different idempotency key', async () => {
  const f = fixture();
  let openAiCalls = 0;
  await withServer(
    {
      env: f.env,
      fetchImpl: async () => {
        openAiCalls += 1;
        return new Response(JSON.stringify({ text: 'unexpected' }), { status: 200 });
      },
    },
    async ({ base }) => {
      const g = await grant(base);
      const wrong = 'session_audio_001:segment:1';
      const response = await fetch(`${base}/api/ai/audio/transcriptions`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${g.json.accessToken}`,
          'X-MedCases-Idempotency-Key': wrong,
          'X-MedCases-Audio-Retention': 'transient-delete',
        },
        body: transcriptionForm({ dedupe: wrong }),
      });
      const json = await response.json();
      assert.equal(response.status, 403);
      assert.equal(json.error, 'audio_grant_request_binding_mismatch');
      assert.equal(openAiCalls, 0);
    },
  );
});

test('tampered grant is rejected before OpenAI', async () => {
  const f = fixture();
  let openAiCalls = 0;
  await withServer(
    {
      env: f.env,
      fetchImpl: async () => {
        openAiCalls += 1;
        return new Response(JSON.stringify({ text: 'unexpected' }), { status: 200 });
      },
    },
    async ({ base }) => {
      const g = await grant(base);
      const token = g.json.accessToken;
      const tampered = `${token.slice(0, -1)}${token.endsWith('A') ? 'B' : 'A'}`;
      const response = await fetch(`${base}/api/ai/audio/transcriptions`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${tampered}`,
          'X-MedCases-Idempotency-Key': 'session_audio_001:segment:0',
          'X-MedCases-Audio-Retention': 'transient-delete',
        },
        body: transcriptionForm(),
      });
      const json = await response.json();
      assert.equal(response.status, 401);
      assert.equal(json.error, 'audio_grant_invalid');
      assert.equal(openAiCalls, 0);
    },
  );
});

test('backend audio owner contains no durable raw-audio filesystem persistence', () => {
  const source = fs.readFileSync(
    require.resolve('../audio_transcription_routes'),
    'utf8',
  );
  for (const forbidden of [
    "require('fs')",
    'writeFile',
    'writeFileSync',
    'createWriteStream',
    'mkdtemp',
    'tmpdir()',
  ]) {
    assert.equal(source.includes(forbidden), false, forbidden);
  }
  assert.match(source, /persistedAudioBytes:\s*0/);
  assert.match(source, /sensitivePayloadLogged:\s*false/);
  assert.match(source, /productionCallsiteWired:\s*false/);
  assert.match(source, /productionCutoverEnabled:\s*false/);
});

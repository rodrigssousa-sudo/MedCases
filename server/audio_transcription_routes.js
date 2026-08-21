'use strict';

const crypto = require('crypto');
const express = require('express');
const rateLimit = require('express-rate-limit');

const GRANT_SCOPE = 'long_form_audio_transcription';
const TRANSCRIPTION_MODEL = 'gpt-transcribe';
const OPENAI_TRANSCRIPTION_ENDPOINT =
  'https://api.openai.com/v1/audio/transcriptions';
const ATTESTATION_SCHEMA = 'medcases.long_form_backend_no_retention.v1';
const ATTESTATION_DOMAIN =
  'medcases.long_form_backend_no_retention.ed25519.v1';
const MAX_AUDIO_BYTES = 25 * 1024 * 1024;
const RAW_MULTIPART_LIMIT = '26mb';
const GRANT_TTL_SECONDS = 10 * 60;
const OPENAI_TIMEOUT_MS = 2 * 60 * 1000;
const MAX_TRANSCRIPT_RESPONSE_BYTES = 2 * 1024 * 1024;

class AudioBackendError extends Error {
  constructor(code, statusCode, { retryable = false } = {}) {
    super(code);
    this.name = 'AudioBackendError';
    this.code = code;
    this.statusCode = statusCode;
    this.retryable = retryable;
  }
}

function safeLog(log, level, message) {
  const target = log && typeof log[level] === 'function' ? log[level] : null;
  if (target) target.call(log, message);
}

function stringEnv(env, key) {
  const value = env?.[key];
  return typeof value === 'string' ? value.trim() : '';
}

function normalizePem(value) {
  return value.includes('\\n') ? value.replace(/\\n/g, '\n') : value;
}

function createRuntime({
  env = process.env,
  fetchImpl = globalThis.fetch,
  now = () => new Date(),
} = {}) {
  const openAiApiKey = stringEnv(env, 'OPENAI_API_KEY');
  const grantSecret = stringEnv(env, 'MEDCASES_AUDIO_GRANT_SECRET');
  const attestationKeyId = stringEnv(
    env,
    'MEDCASES_AUDIO_ATTESTATION_KEY_ID',
  );
  const privateKeyPemRaw = stringEnv(
    env,
    'MEDCASES_AUDIO_ATTESTATION_PRIVATE_KEY_PEM',
  );

  let attestationPrivateKey = null;
  let configurationError = null;

  if (typeof fetchImpl !== 'function') {
    configurationError = 'audio_backend_fetch_unavailable';
  } else if (openAiApiKey.length < 20) {
    configurationError = 'audio_backend_openai_key_missing';
  } else if (grantSecret.length < 32) {
    configurationError = 'audio_backend_grant_secret_missing_or_weak';
  } else if (!/^[A-Za-z0-9._-]{1,64}$/.test(attestationKeyId)) {
    configurationError = 'audio_backend_attestation_key_id_invalid';
  } else if (!privateKeyPemRaw) {
    configurationError = 'audio_backend_attestation_private_key_missing';
  } else {
    try {
      const key = crypto.createPrivateKey(normalizePem(privateKeyPemRaw));
      if (key.asymmetricKeyType !== 'ed25519') {
        throw new Error('not_ed25519');
      }
      attestationPrivateKey = key;
    } catch (_) {
      configurationError = 'audio_backend_attestation_private_key_invalid';
    }
  }

  return {
    ready: configurationError === null,
    configurationError,
    openAiApiKey,
    grantSecret,
    attestationKeyId,
    attestationPrivateKey,
    fetchImpl,
    now,
  };
}

function base64UrlJson(value) {
  return Buffer.from(JSON.stringify(value), 'utf8').toString('base64url');
}

function hmacBase64Url(secret, payload) {
  return crypto
    .createHmac('sha256', secret)
    .update(payload, 'utf8')
    .digest('base64url');
}

function issueGrantToken({ runtime, uid, sessionId, deduplicationKey }) {
  const nowDate = runtime.now();
  const issuedEpoch = Math.floor(nowDate.getTime() / 1000);
  const expiresEpoch = issuedEpoch + GRANT_TTL_SECONDS;
  const claims = {
    v: 1,
    uid,
    sessionId,
    deduplicationKey,
    scope: GRANT_SCOPE,
    iat: issuedEpoch,
    exp: expiresEpoch,
    nonce: crypto.randomBytes(16).toString('base64url'),
  };
  const encoded = base64UrlJson(claims);
  const signature = hmacBase64Url(runtime.grantSecret, encoded);
  return {
    accessToken: `mcg1.${encoded}.${signature}`,
    issuedAtUtc: new Date(issuedEpoch * 1000).toISOString(),
    expiresAtUtc: new Date(expiresEpoch * 1000).toISOString(),
  };
}

function constantTimeEqualBase64Url(left, right) {
  let leftBytes;
  let rightBytes;
  try {
    leftBytes = Buffer.from(left, 'base64url');
    rightBytes = Buffer.from(right, 'base64url');
  } catch (_) {
    return false;
  }
  if (leftBytes.length === 0 || leftBytes.length !== rightBytes.length) {
    return false;
  }
  return crypto.timingSafeEqual(leftBytes, rightBytes);
}

function verifyGrantToken(runtime, token) {
  if (typeof token !== 'string' || token.length < 32 || token.length > 4096) {
    throw new AudioBackendError('audio_grant_invalid', 401);
  }

  const parts = token.split('.');
  if (parts.length !== 3 || parts[0] !== 'mcg1') {
    throw new AudioBackendError('audio_grant_invalid', 401);
  }

  const expected = hmacBase64Url(runtime.grantSecret, parts[1]);
  if (!constantTimeEqualBase64Url(parts[2], expected)) {
    throw new AudioBackendError('audio_grant_invalid', 401);
  }

  let claims;
  try {
    claims = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
  } catch (_) {
    throw new AudioBackendError('audio_grant_invalid', 401);
  }

  if (
    !claims ||
    claims.v !== 1 ||
    typeof claims.uid !== 'string' ||
    claims.uid.length < 1 ||
    claims.uid.length > 256 ||
    !validSessionId(claims.sessionId) ||
    !validDedupe(claims.deduplicationKey) ||
    claims.scope !== GRANT_SCOPE ||
    !Number.isInteger(claims.iat) ||
    !Number.isInteger(claims.exp) ||
    typeof claims.nonce !== 'string' ||
    claims.nonce.length < 16
  ) {
    throw new AudioBackendError('audio_grant_invalid', 401);
  }

  const nowEpoch = Math.floor(runtime.now().getTime() / 1000);
  if (claims.exp <= nowEpoch || claims.iat > nowEpoch + 30) {
    throw new AudioBackendError('audio_grant_expired_or_not_yet_valid', 401);
  }
  if (claims.exp - claims.iat > GRANT_TTL_SECONDS) {
    throw new AudioBackendError('audio_grant_invalid_ttl', 401);
  }

  return claims;
}

function bearerToken(req) {
  const header = req.headers.authorization ?? '';
  const match = String(header).match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() ?? '';
}

function validSessionId(value) {
  return typeof value === 'string' && /^[A-Za-z0-9._-]{1,96}$/.test(value);
}

function validDedupe(value) {
  return (
    typeof value === 'string' &&
    value.trim().length > 0 &&
    value.length <= 240
  );
}

function validateGrantRequest(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    throw new AudioBackendError('audio_grant_body_invalid', 400);
  }
  const { sessionId, deduplicationKey, scope } = body;
  if (!validSessionId(sessionId)) {
    throw new AudioBackendError('audio_grant_session_invalid', 400);
  }
  if (!validDedupe(deduplicationKey)) {
    throw new AudioBackendError('audio_grant_deduplication_invalid', 400);
  }
  if (scope !== GRANT_SCOPE) {
    throw new AudioBackendError('audio_grant_scope_invalid', 400);
  }
  return { sessionId, deduplicationKey, scope };
}

async function parseMultipartBuffer(req) {
  const contentType = req.headers['content-type'];
  if (
    typeof contentType !== 'string' ||
    !contentType.toLowerCase().startsWith('multipart/form-data;')
  ) {
    throw new AudioBackendError('audio_multipart_content_type_required', 415);
  }
  if (!Buffer.isBuffer(req.body)) {
    throw new AudioBackendError('audio_multipart_body_missing', 400);
  }

  let form;
  try {
    const request = new Request('http://medcases.local/audio', {
      method: 'POST',
      headers: { 'content-type': contentType },
      body: req.body,
    });
    form = await request.formData();
  } catch (_) {
    throw new AudioBackendError('audio_multipart_parse_failed', 400);
  }

  const allowed = new Set([
    'sessionId',
    'idempotencyKey',
    'model',
    'language',
    'prompt',
    'keywordsJson',
    'contentType',
    'contentLengthBytes',
    'audio',
  ]);
  for (const key of form.keys()) {
    if (!allowed.has(key)) {
      throw new AudioBackendError('audio_multipart_unexpected_field', 400);
    }
  }
  for (const key of allowed) {
    if (form.getAll(key).length !== 1) {
      throw new AudioBackendError('audio_multipart_field_count_invalid', 400);
    }
  }

  const text = (key) => {
    const value = form.get(key);
    if (typeof value !== 'string') {
      throw new AudioBackendError('audio_multipart_text_field_invalid', 400);
    }
    return value;
  };

  const audio = form.get('audio');
  if (
    !audio ||
    typeof audio !== 'object' ||
    typeof audio.arrayBuffer !== 'function' ||
    typeof audio.size !== 'number'
  ) {
    throw new AudioBackendError('audio_file_missing', 400);
  }

  const filename = typeof audio.name === 'string' ? audio.name : '';
  if (!filename.toLowerCase().endsWith('.m4a')) {
    throw new AudioBackendError('audio_file_extension_invalid', 400);
  }

  const partType = typeof audio.type === 'string' ? audio.type.toLowerCase() : '';
  if (
    partType &&
    partType !== 'audio/mp4' &&
    partType !== 'audio/x-m4a' &&
    partType !== 'application/octet-stream'
  ) {
    throw new AudioBackendError('audio_file_part_content_type_invalid', 415);
  }

  const sessionId = text('sessionId');
  const idempotencyKey = text('idempotencyKey');
  const model = text('model');
  const language = text('language');
  const prompt = text('prompt');
  const keywordsJson = text('keywordsJson');
  const declaredContentType = text('contentType');
  const declaredBytesRaw = text('contentLengthBytes');

  if (!validSessionId(sessionId)) {
    throw new AudioBackendError('audio_session_invalid', 400);
  }
  if (!validDedupe(idempotencyKey)) {
    throw new AudioBackendError('audio_idempotency_invalid', 400);
  }
  if (model !== TRANSCRIPTION_MODEL) {
    throw new AudioBackendError('audio_model_invalid', 400);
  }
  if (language !== 'pt' && language !== 'es') {
    throw new AudioBackendError('audio_language_invalid', 400);
  }
  if (prompt.length > 4000) {
    throw new AudioBackendError('audio_prompt_too_large', 400);
  }
  if (declaredContentType !== 'audio/mp4') {
    throw new AudioBackendError('audio_declared_content_type_invalid', 415);
  }

  const declaredBytes = Number(declaredBytesRaw);
  if (
    !Number.isSafeInteger(declaredBytes) ||
    declaredBytes < 1 ||
    declaredBytes > MAX_AUDIO_BYTES
  ) {
    throw new AudioBackendError('audio_declared_size_invalid', 400);
  }
  if (audio.size !== declaredBytes || audio.size > MAX_AUDIO_BYTES) {
    throw new AudioBackendError('audio_actual_size_mismatch', 400);
  }

  let keywords;
  try {
    keywords = JSON.parse(keywordsJson);
  } catch (_) {
    throw new AudioBackendError('audio_keywords_json_invalid', 400);
  }
  if (
    !Array.isArray(keywords) ||
    keywords.length > 120 ||
    keywords.some((item) => typeof item !== 'string') ||
    keywordsJson.length > 16000
  ) {
    throw new AudioBackendError('audio_keywords_invalid', 400);
  }

  const audioBuffer = Buffer.from(await audio.arrayBuffer());
  if (audioBuffer.length !== declaredBytes) {
    audioBuffer.fill(0);
    throw new AudioBackendError('audio_buffer_size_mismatch', 400);
  }

  return {
    sessionId,
    idempotencyKey,
    model,
    language,
    prompt,
    keywords,
    declaredContentType,
    declaredBytes,
    filename,
    audioBuffer,
  };
}

function buildOpenAiPrompt(prompt, keywords) {
  const cleanKeywords = keywords
    .map((item) => item.trim())
    .filter(Boolean)
    .slice(0, 120);
  const suffix = cleanKeywords.length
    ? `\nVocabulário clínico prioritário: ${cleanKeywords.join(', ')}`
    : '';
  return `${prompt}${suffix}`.slice(0, 4000);
}

async function readBoundedText(response, maximumBytes) {
  if (!response.body || typeof response.body.getReader !== 'function') {
    const text = await response.text();
    if (Buffer.byteLength(text, 'utf8') > maximumBytes) {
      throw new AudioBackendError('openai_response_too_large', 502);
    }
    return text;
  }

  const reader = response.body.getReader();
  const chunks = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maximumBytes) {
      try { await reader.cancel(); } catch (_) {}
      throw new AudioBackendError('openai_response_too_large', 502);
    }
    chunks.push(Buffer.from(value));
  }
  return Buffer.concat(chunks, total).toString('utf8');
}

async function callOpenAiTranscription(runtime, parsed) {
  const form = new FormData();
  form.append(
    'file',
    new Blob([parsed.audioBuffer], { type: 'audio/mp4' }),
    parsed.filename,
  );
  form.append('model', TRANSCRIPTION_MODEL);
  form.append('language', parsed.language);
  const prompt = buildOpenAiPrompt(parsed.prompt, parsed.keywords);
  if (prompt) form.append('prompt', prompt);

  let response;
  try {
    response = await runtime.fetchImpl(OPENAI_TRANSCRIPTION_ENDPOINT, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${runtime.openAiApiKey}`,
        Accept: 'application/json',
      },
      body: form,
      signal: AbortSignal.timeout(OPENAI_TIMEOUT_MS),
    });
  } catch (_) {
    throw new AudioBackendError('openai_transcription_network_failure', 503, {
      retryable: true,
    });
  }

  if (!response.ok) {
    const retryable =
      response.status === 408 ||
      response.status === 425 ||
      response.status === 429 ||
      response.status >= 500;
    throw new AudioBackendError(
      'openai_transcription_upstream_failure',
      retryable ? 503 : 502,
      { retryable },
    );
  }

  const body = await readBoundedText(response, MAX_TRANSCRIPT_RESPONSE_BYTES);
  let decoded;
  try {
    decoded = JSON.parse(body);
  } catch (_) {
    throw new AudioBackendError('openai_transcription_invalid_json', 502);
  }
  const transcript = decoded?.text;
  if (
    typeof transcript !== 'string' ||
    transcript.trim().length === 0 ||
    transcript.length > 1_000_000
  ) {
    throw new AudioBackendError('openai_transcription_text_invalid', 502);
  }
  return transcript;
}

function canonicalAttestationPayload(attestation, keyId) {
  return [
    ATTESTATION_DOMAIN,
    keyId,
    attestation.schemaVersion,
    attestation.idempotencyKey,
    attestation.requestReceivedAtUtc,
    attestation.upstreamCompletedAtUtc,
    attestation.temporaryAudioDeletedAtUtc,
    attestation.temporaryAudioDeleted ? '1' : '0',
    String(attestation.persistedAudioBytes),
    attestation.sensitivePayloadLogged ? '1' : '0',
  ].join('\n');
}

function signAttestation(runtime, attestation) {
  const canonical = canonicalAttestationPayload(
    attestation,
    runtime.attestationKeyId,
  );
  const signature = crypto.sign(
    null,
    Buffer.from(canonical, 'utf8'),
    runtime.attestationPrivateKey,
  );
  return `ed25519.${runtime.attestationKeyId}.${signature.toString('base64url')}`;
}

function deterministicResultRef(runtime, idempotencyKey) {
  const digest = crypto
    .createHmac('sha256', runtime.grantSecret)
    .update(`result-ref\n${idempotencyKey}`, 'utf8')
    .digest('hex')
    .slice(0, 32);
  return `backend://audio/${digest}`;
}

function sendError(res, error, requestId) {
  const normalized =
    error instanceof AudioBackendError
      ? error
      : new AudioBackendError('audio_backend_internal_error', 500, {
          retryable: true,
        });
  return res.status(normalized.statusCode).json({
    error: normalized.code,
    retryable: normalized.retryable,
    requestId,
  });
}

function wrapRawParser(parser) {
  return (req, res, next) => {
    parser(req, res, (error) => {
      if (!error) return next();
      const statusCode = error?.type === 'entity.too.large' ? 413 : 400;
      return res.status(statusCode).json({
        error: statusCode === 413
          ? 'audio_multipart_too_large'
          : 'audio_multipart_body_invalid',
        retryable: false,
      });
    });
  };
}

function registerAudioTranscriptionRoutes({
  app,
  authenticateFirebaseToken,
  log,
  isProd = false,
  env = process.env,
  fetchImpl = globalThis.fetch,
  now,
}) {
  if (!app || typeof app.post !== 'function') {
    throw new TypeError('Express app is required.');
  }
  if (typeof authenticateFirebaseToken !== 'function') {
    throw new TypeError('Firebase auth middleware is required.');
  }

  const runtime = createRuntime({ env, fetchImpl, now });
  const limiter = rateLimit({
    windowMs: 60_000,
    max: 30,
    standardHeaders: true,
    legacyHeaders: false,
    skip: () => !isProd,
    message: { error: 'audio_rate_limit', retryable: true },
  });
  const grantJson = express.json({ limit: '16kb' });
  const multipartRaw = wrapRawParser(
    express.raw({ type: 'multipart/form-data', limit: RAW_MULTIPART_LIMIT }),
  );

  app.post(
    '/api/ai/audio/grant',
    limiter,
    grantJson,
    authenticateFirebaseToken,
    (req, res) => {
      const requestId =
        req.headers['x-request-id'] ?? `audio_${crypto.randomUUID()}`;
      res.setHeader('X-Request-ID', requestId);

      if (!runtime.ready) {
        safeLog(log, 'warn', `[${requestId}] audio backend not configured`);
        return res.status(503).json({
          error: 'audio_backend_not_configured',
          retryable: false,
          requestId,
        });
      }

      try {
        const { sessionId, deduplicationKey, scope } =
          validateGrantRequest(req.body);
        const uid = req.auth?.uid;
        if (typeof uid !== 'string' || uid.length < 1 || uid.length > 256) {
          throw new AudioBackendError('audio_grant_firebase_identity_missing', 401);
        }
        const token = issueGrantToken({
          runtime,
          uid,
          sessionId,
          deduplicationKey,
        });
        safeLog(log, 'info', `[${requestId}] audio grant issued`);
        return res.json({
          sessionId,
          deduplicationKey,
          scope,
          accessToken: token.accessToken,
          issuedAtUtc: token.issuedAtUtc,
          expiresAtUtc: token.expiresAtUtc,
        });
      } catch (error) {
        safeLog(log, 'warn', `[${requestId}] audio grant rejected`);
        return sendError(res, error, requestId);
      }
    },
  );

  app.post(
    '/api/ai/audio/transcriptions',
    limiter,
    multipartRaw,
    async (req, res) => {
      const requestId =
        req.headers['x-request-id'] ?? `audio_${crypto.randomUUID()}`;
      res.setHeader('X-Request-ID', requestId);

      if (!runtime.ready) {
        safeLog(log, 'warn', `[${requestId}] audio backend not configured`);
        return res.status(503).json({
          error: 'audio_backend_not_configured',
          retryable: false,
          requestId,
        });
      }

      let audioBuffer = null;
      let parsed = null;
      const requestReceivedAtUtc = runtime.now().toISOString();

      try {
        const token = bearerToken(req);
        const claims = verifyGrantToken(runtime, token);
        parsed = await parseMultipartBuffer(req);
        audioBuffer = parsed.audioBuffer;

        const retentionHeader = req.headers['x-medcases-audio-retention'];
        if (retentionHeader !== 'transient-delete') {
          throw new AudioBackendError('audio_retention_header_invalid', 400);
        }
        const headerIdempotency = req.headers['x-medcases-idempotency-key'];
        if (
          typeof headerIdempotency !== 'string' ||
          headerIdempotency !== parsed.idempotencyKey
        ) {
          throw new AudioBackendError('audio_idempotency_header_mismatch', 400);
        }
        if (
          claims.sessionId !== parsed.sessionId ||
          claims.deduplicationKey !== parsed.idempotencyKey ||
          claims.scope !== GRANT_SCOPE
        ) {
          throw new AudioBackendError('audio_grant_request_binding_mismatch', 403);
        }

        const transcript = await callOpenAiTranscription(runtime, parsed);
        const upstreamCompletedAtUtc = runtime.now().toISOString();

        // MedCases backend keeps no durable raw audio. Before signing the
        // attestation, explicitly zero/release the request buffer it owns.
        audioBuffer.fill(0);
        audioBuffer = null;
        parsed.audioBuffer = null;
        const temporaryAudioDeletedAtUtc = runtime.now().toISOString();

        const attestation = {
          schemaVersion: ATTESTATION_SCHEMA,
          idempotencyKey: parsed.idempotencyKey,
          requestReceivedAtUtc,
          upstreamCompletedAtUtc,
          temporaryAudioDeletedAtUtc,
          temporaryAudioDeleted: true,
          persistedAudioBytes: 0,
          sensitivePayloadLogged: false,
        };
        const attestationToken = signAttestation(runtime, attestation);

        safeLog(log, 'info', `[${requestId}] audio transcription completed`);
        return res.json({
          idempotencyKey: parsed.idempotencyKey,
          transcript,
          resultRef: deterministicResultRef(runtime, parsed.idempotencyKey),
          noRetentionAttestation: {
            ...attestation,
            attestationToken,
          },
        });
      } catch (error) {
        safeLog(log, 'warn', `[${requestId}] audio transcription rejected`);
        return sendError(res, error, requestId);
      } finally {
        if (Buffer.isBuffer(audioBuffer)) {
          audioBuffer.fill(0);
        }
        if (parsed && Buffer.isBuffer(parsed.audioBuffer)) {
          parsed.audioBuffer.fill(0);
          parsed.audioBuffer = null;
        }
        if (Buffer.isBuffer(req.body)) {
          req.body.fill(0);
          req.body = null;
        }
      }
    },
  );

  return Object.freeze({
    ready: runtime.ready,
    configurationError: runtime.configurationError,
    grantScope: GRANT_SCOPE,
    transcriptionModel: TRANSCRIPTION_MODEL,
    openAiEndpoint: OPENAI_TRANSCRIPTION_ENDPOINT,
    rawAudioDurablePersistenceAllowed: false,
    sensitivePayloadLoggingAllowed: false,
    productionCallsiteWired: false,
    productionCutoverEnabled: false,
  });
}

module.exports = {
  ATTESTATION_DOMAIN,
  ATTESTATION_SCHEMA,
  GRANT_SCOPE,
  MAX_AUDIO_BYTES,
  OPENAI_TRANSCRIPTION_ENDPOINT,
  TRANSCRIPTION_MODEL,
  canonicalAttestationPayload,
  createRuntime,
  issueGrantToken,
  registerAudioTranscriptionRoutes,
  verifyGrantToken,
};

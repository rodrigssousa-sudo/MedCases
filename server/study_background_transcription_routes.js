const {classifyBinary,assertBinaryBinding}=require('./binary_media_classifier');
const {combineProofs,digest}=require('./audio_media_budget');
const {MonthlyUsageOwner}=require('./monthly_usage_owner');
'use strict';

const crypto = require('crypto');
const {assertUsageReservation,usageReceipt}=require('./usage_reservation_guard');
const express = require('express');
const { getApps } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const {
  getFirestore,
  Timestamp,
} = require('firebase-admin/firestore');

const COLLECTION = '_study_background_transcription_jobs';
const GRANT_SCOPE = 'study-background-transcription-v1';
const MAX_SEGMENTS = 64;
const MAX_AUDIO_BYTES = 25 * 1024 * 1024;
const JOB_TTL_MS = 8 * 60 * 60 * 1000;
const LEASE_MS = 3 * 60 * 1000;
const OPENAI_TIMEOUT_MS = 150000;
const OPENAI_ENDPOINT = 'https://api.openai.com/v1/audio/transcriptions';
const MODEL = 'gpt-transcribe';
const {createTranscriptionTempStorage} = require('./transcription_temp_storage');
const {TranscriptionDurableQueue, canonical} = require('./transcription_durable_queue');
const {AssemblyAiProvider,LegacyTranscriptionProvider} = require('./assemblyai_provider');
const {MedCasesTranscriptionService} = require('./medcases_transcription_service');
const {selectedProvider,profileOptions,providerGateError} = require('./transcription_profiles');
let durableQueue;
function queue() {
  if (durableQueue) return durableQueue;
  const rt = runtime(), storage = createTranscriptionTempStorage();
  if (!rt.enabled || !storage) return null;
  const legacy = new LegacyTranscriptionProvider((body,mime,index,proof)=>transcribeBuffer(rt.openAiKey,body,mime,index,proof));
  const providers={legacy};
  if(process.env.ASSEMBLYAI_API_KEY) providers.assemblyai=new AssemblyAiProvider({apiKey:process.env.ASSEMBLYAI_API_KEY});
  durableQueue = new TranscriptionDurableQueue({db:getFirestore(rt.app),storage,
    centralService:new MedCasesTranscriptionService({providers}),transcribe:legacy.transcribe});
  return durableQueue;
}

function base64urlJson(value) {
  return Buffer.from(JSON.stringify(value), 'utf8').toString('base64url');
}

function signGrant(secret, payload) {
  const encoded = base64urlJson(payload);
  const signature = crypto
    .createHmac('sha256', secret)
    .update(encoded, 'utf8')
    .digest('base64url');
  return `${encoded}.${signature}`;
}

function verifyGrant(secret, token) {
  if (typeof token !== 'string' || token.length < 20) {
    throw new Error('study_grant_invalid');
  }
  const parts = token.split('.');
  if (parts.length !== 2) {
    throw new Error('study_grant_invalid');
  }
  const expected = crypto
    .createHmac('sha256', secret)
    .update(parts[0], 'utf8')
    .digest('base64url');
  const a = Buffer.from(expected);
  const b = Buffer.from(parts[1]);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
    throw new Error('study_grant_invalid');
  }
  const payload = JSON.parse(
    Buffer.from(parts[0], 'base64url').toString('utf8'),
  );
  if (
    payload.scope !== GRANT_SCOPE ||
    !Number.isFinite(payload.exp) ||
    payload.exp < Date.now()
  ) {
    throw new Error('study_grant_expired_or_invalid');
  }
  return payload;
}

function runtime() {
  const secret = String(process.env.MEDCASES_AUDIO_GRANT_SECRET || '');
  const openAiKey = String(process.env.OPENAI_API_KEY || '');
  const apps = getApps();
  return {
    secret,
    openAiKey,
    app: apps.length > 0 ? apps[0] : null,
    enabled: secret.length >= 32 && apps.length > 0 &&
      (openAiKey.length >= 20 || (process.env.ASSEMBLYAI_TRANSCRIPTION_ENABLED==='true' && Boolean(process.env.ASSEMBLYAI_API_KEY))),
  };
}

function studyAuthorization(req, secret) {
  const raw = String(req.headers.authorization || '');
  const match = /^Study\s+(.+)$/.exec(raw);
  if (!match) {
    throw new Error('study_grant_missing');
  }
  return verifyGrant(secret, match[1]);
}

async function firebaseUid(req, app) {
  const raw = String(req.headers.authorization || '');
  const match = /^Bearer\s+(.+)$/.exec(raw);
  if (!match) {
    throw new Error('firebase_identity_missing');
  }
  const decoded = await getAuth(app).verifyIdToken(match[1], true);
  if (!decoded || typeof decoded.uid !== 'string' || decoded.uid.length < 1) {
    throw new Error('firebase_identity_invalid');
  }
  return decoded.uid;
}

function validJobId(value) {
  return /^[A-Za-z0-9_-]{16,96}$/.test(String(value || ''));
}

function validIndex(value, expected) {
  const n = Number(value);
  return Number.isInteger(n) && n >= 0 && n < expected;
}

async function transcribeBuffer(openAiKey, body, mimeType, index, binaryProof) {
  assertBinaryBinding(binaryProof,body);
  const form = new FormData();
  form.append('model', MODEL);
  form.append(
    'file',
    new Blob([body], { type: mimeType || 'audio/mp4' }),
    `segment_${index}.${mimeType === 'audio/wav' ? 'wav' : 'm4a'}`,
  );
  form.append(
    'prompt',
    'Educational medical class transcription. Preserve numbers, doses, units, classifications and negations. Do not summarize.',
  );

  const response = await fetch(OPENAI_ENDPOINT, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${openAiKey}`,
    },
    body: form,
    signal: AbortSignal.timeout(OPENAI_TIMEOUT_MS),
  });

  const json = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`openai_transcription_${response.status}`);
  }
  const transcript = String(json.text || '').trim();
  if (!transcript) {
    throw new Error('openai_transcription_empty');
  }
  return transcript;
}

async function deleteJobTree(db, jobRef) {
  const current=(await jobRef.get()).data();
  if(current?.provider==='assemblyai')return queue().logical.cancel(jobRef);
  const segments = await jobRef.collection('segments').get();
  let batch = db.batch();
  let count = 0;
  for (const doc of segments.docs) {
    const value = doc.data();
    if (value.objectKey) {
      const storage = createTranscriptionTempStorage();
      if (!storage) throw Error('TEMP_STORAGE_UNAVAILABLE');
      await storage.remove(value.objectKey);
    }
    batch.delete(doc.ref);
    count += 1;
    if (count >= 400) {
      await batch.commit();
      batch = db.batch();
      count = 0;
    }
  }
  if (count > 0) {
    await batch.commit();
  }
  await jobRef.delete();
}

async function cleanupExpiredJobs() {
  const rt = runtime();
  if (!rt.enabled) {
    return;
  }
  const db = getFirestore(rt.app);
  const expired = await db
    .collection(COLLECTION)
    .where('expiresAt', '<=', Timestamp.now())
    .limit(10)
    .get();
  for (const doc of expired.docs) {
    await deleteJobTree(db, doc.ref).catch(() => {});
  }
}

function registerStudyBackgroundTranscriptionRoutes(app, {startWorker=true}={}) {
  if (!app || typeof app.get !== 'function') {
    throw new Error('study_background_router_app_invalid');
  }

  app.get(
    '/api/ai/study/background-transcription/capabilities',
    (req, res) => {
      const rt = runtime();
      res.status(200).json({
        enabled: rt.enabled && Boolean(queue()),
        schemaVersion: 1,
        maxSegments: MAX_SEGMENTS,
        maxSegmentBytes: MAX_AUDIO_BYTES,
        audioPersistence: Boolean(queue()),
        uploadAcknowledgement: queue() ? 'durable-queue-202' : 'unavailable',
        transcriptCheckpoint: 'firestore-transient',
        model: MODEL,
      });
    },
  );

  app.post(
    '/api/ai/study/background-transcription/jobs',
    express.json({ limit: '32kb' }),
    async (req, res) => {
      let uid, usage, db;
      try {
        const rt = runtime();
        if (!rt.enabled || !queue()) {
          return res.status(503).json({ error: 'study_background_disabled' });
        }

        uid = await firebaseUid(req, rt.app);
        db = getFirestore(rt.app);
        usage = await assertUsageReservation(db,uid,req.headers);
        const expectedSegments = Number(req.body?.expectedSegments);
        if (
          !Number.isInteger(expectedSegments) ||
          expectedSegments < 1 ||
          expectedSegments > MAX_SEGMENTS
        ) {
          throw Error('EXPECTED_SEGMENTS_INVALID');
        }

        const locale = req.body?.locale === 'es' ? 'es' : 'pt';
        const sourceId = String(req.body?.sourceId || '').slice(0, 160);
        const jobId = crypto.createHash('sha256').update(JSON.stringify(usage)).digest('hex');
        const now = Date.now();
        const exp = now + JOB_TTL_MS;

        const jobRef = db.collection(COLLECTION).doc(jobId);
        const reservation = await db.collection('usageReservations').doc(usageReceipt(usage).id).get();
        if (expectedSegments !== (reservation.data().executionCount || 1)) throw Error('EXECUTION_PLAN_MISMATCH');
        await db.runTransaction(async tx => {
          // Release and create conflict on the same reservation read.
          const receipt=usageReceipt(usage);
          const current=await tx.get(db.collection('usageReservations').doc(receipt.id));
          const allocation=current.data();
          if(!allocation || allocation.uid!==uid || allocation.attempt!==receipt.attempt || !['reserved','executing'].includes(allocation.state))throw Error('SERVER_QUOTA_RESERVATION_INVALID');
          const existing = await tx.get(jobRef);
          if (existing.exists) {
            const value = existing.data();
            if(value.deleted)throw Error('study_job_deleted');
            if (value.uid !== uid || value.expectedSegments !== expectedSegments) throw Error('study_job_binding_invalid');
            tx.set(jobRef, {expiresAt:Timestamp.fromMillis(exp)}, {merge:true});
            return;
          }
          tx.set(jobRef, {
          uid,
          ownerUid:uid,
          sessionId:sourceId,
          provider:selectedProvider(process.env,uid),
          mode:req.body?.mode || 'studyRecording',
          conversation:req.body?.conversation === true,
          usage,
          expectedSegments,
          locale,
          sourceId,
          educationalOnly: true,
          state: 'queued',
          workerPending: false,
          createdAt: Timestamp.fromMillis(now),
          updatedAt: Timestamp.fromMillis(now),
          expiresAt: Timestamp.fromMillis(exp),
          });
        });

        const grant = signGrant(rt.secret, {
          scope: GRANT_SCOPE,
          jobId,
          uid,
          expectedSegments,
          iat: now,
          exp,
        });

        return res.status(201).json({
          schemaVersion: 1,
          jobId,
          grant,
          expectedSegments,
          uploadBasePath:
            `/api/ai/study/background-transcription/jobs/${jobId}/segments`,
          statusPath:
            `/api/ai/study/background-transcription/jobs/${jobId}`,
        });
      } catch (error) {
        if(db&&uid&&usage)await new MonthlyUsageOwner({db}).failBeforeExecution(uid,usageReceipt(usage)).catch(()=>{});
        const gate=providerGateError(error);
        if(gate)return res.status(gate.retryable?503:403).json(gate);
        const auth=/^(AUTH_REQUIRED|SERVER_QUOTA_RESERVATION_REQUIRED|SERVER_QUOTA_RESERVATION_INVALID)$/.test(error?.message||'');
        const invalid=['EXPECTED_SEGMENTS_INVALID','EXECUTION_PLAN_MISMATCH'].includes(error?.message);
        const code=auth?'AUTH_FAILURE':invalid?error.message:'JOB_CREATE_FAILED';
        return res.status(auth?401:invalid?400:503).json({code,error:code,retryable:!auth&&!invalid});
      }
    },
  );

  app.put(
    '/api/ai/study/background-transcription/jobs/:jobId/segments/:index',
    (req, _res, next) => {req.receivedAt = Date.now(); next();},
    express.raw({
      type: 'application/octet-stream',
      limit: `${MAX_AUDIO_BYTES}b`,
    }),
    async (req, res) => {
      let body = null;
      try {
        const rt = runtime();
        if (!rt.enabled || !queue()) {
          return res.status(503).json({ error: 'study_background_disabled' });
        }

        const grant = studyAuthorization(req, rt.secret);
        const jobId = String(req.params.jobId || '');
        if (!validJobId(jobId) || grant.jobId !== jobId) {
          return res.status(403).json({ error: 'study_job_binding_invalid' });
        }
        const expected = Number(grant.expectedSegments);
        const index = Number(req.params.index);
        if (!validIndex(index, expected)) {
          return res.status(400).json({ error: 'segment_index_invalid' });
        }

        body = Buffer.isBuffer(req.body) ? req.body : Buffer.alloc(0);
        if (body.length < 1 || body.length > MAX_AUDIO_BYTES) {
          return res.status(413).json({ error: 'segment_size_invalid' });
        }

        const db = getFirestore(rt.app);
        const jobRef = db.collection(COLLECTION).doc(jobId);
        const jobSnap = await jobRef.get();
        if (!jobSnap.exists) {
          return res.status(404).json({ error: 'study_job_missing' });
        }
        const job = jobSnap.data();
        if(job.deleted)return res.status(410).json({error:'study_job_deleted'});
        if (
          job.uid !== grant.uid ||
          Number(job.expectedSegments) !== expected
        ) {
          return res.status(403).json({ error: 'study_job_binding_invalid' });
        }

        const existing = await jobRef.collection('segments').doc(String(index)).get();
        const value = existing.exists ? existing.data() : {};
        // Existing completed/active work is readable after its reservation settles.
        // New execution still goes through the unchanged reservation/owner guards.
        if (!(value.state === 'done' || ['processing','queued','uploading'].includes(value.state))) {
          await assertUsageReservation(db, grant.uid, job.usage || {});
        }
        const result = await queue().enqueue(jobRef, job, index, body, req.receivedAt || Date.now());
        if (result.state === 'terminal_error') return res.status(409).json({error:'EXECUTION_RESULT_UNAVAILABLE', retryable:false});
        return res.status(result.state === 'completed' ? 200 : 202).json({segmentIndex:index, ...result});
      } catch (error) {
        const binding = /binding|grant|identity|RESERVATION|QUOTA/.test(error.message || '');
        return res.status(binding ? 403 : error.message === 'SEGMENT_CONTENT_CONFLICT' ? 409 : 503)
          .json({error:binding ? 'study_authorization_failed' : 'UPLOAD_PROCESSING_FAILED', retryable:!binding});
      } finally {
        if (Buffer.isBuffer(body)) {
          body.fill(0);
        }
      }
    },
  );

  app.get(
    '/api/ai/study/background-transcription/jobs/:jobId',
    async (req, res) => {
      try {
        const rt = runtime();
        if (!rt.enabled || !queue()) {
          return res.status(503).json({ error: 'study_background_disabled' });
        }
        const grant = studyAuthorization(req, rt.secret);
        const jobId = String(req.params.jobId || '');
        if (!validJobId(jobId) || grant.jobId !== jobId) {
          return res.status(403).json({ error: 'study_job_binding_invalid' });
        }

        const db = getFirestore(rt.app);
        const jobRef = db.collection(COLLECTION).doc(jobId);
        const jobSnap = await jobRef.get();
        if (!jobSnap.exists) {
          return res.status(404).json({ error: 'study_job_missing' });
        }
        const job = jobSnap.data();
        if(job.deleted)return res.status(410).json({error:'study_job_deleted'});
        if (job.uid !== grant.uid) {
          return res.status(403).json({ error: 'study_job_binding_invalid' });
        }

        const before = await jobRef.collection('segments').get();
        for (const doc of before.docs) await queue().recover(jobRef, job, doc.ref);
        const aggregate = await queue().aggregate(jobRef, job);
        const segmentSnap = await jobRef.collection('segments').get();
        const transcripts = segmentSnap.docs
          .map((doc) => doc.data())
          .filter((value) => value.state === 'done' && value.transcript)
          .map((value) => ({
            segmentIndex: Number(value.index),
            transcript: String(value.transcript),
          }))
          .sort((a, b) => a.segmentIndex - b.segmentIndex);

        const expectedSegments = Number(job.expectedSegments);
        return res.status(200).json({
          jobId,
          expectedSegments,
          state: aggregate.state,
          completedSegments: transcripts.length,
          failedSegments: aggregate.failed,
          pendingSegments: Math.max(0, expectedSegments-transcripts.length-aggregate.failed),
          segments: segmentSnap.docs.map(doc => {
            const v=doc.data(); const status=job.provider==='assemblyai'&&['retryable_error','terminal_error'].includes(aggregate.state)?aggregate.state:canonical(v);
            return {segmentIndex:v.index, state:['retryable_error','terminal_error'].includes(status)?'failed':status,
              canonicalState:status, retryable:v.retryable ?? status==='retryable_error', errorCategory:v.errorCategory || null,
              timings:v.timings || {}, attemptCount:v.attemptCount || 0};
          }),
          complete: transcripts.length === expectedSegments,
          transcripts,
        });
      } catch (error) {
        return res.status(401).json({
          error: String(error?.message || 'study_job_status_failed'),
        });
      }
    },
  );

  app.delete(
    '/api/ai/study/background-transcription/jobs/:jobId',
    async (req, res) => {
      try {
        const rt = runtime();
        if (!rt.enabled || !queue()) {
          return res.status(503).json({ error: 'study_background_disabled' });
        }
        const grant = studyAuthorization(req, rt.secret);
        const jobId = String(req.params.jobId || '');
        if (!validJobId(jobId) || grant.jobId !== jobId) {
          return res.status(403).json({ error: 'study_job_binding_invalid' });
        }
        const db = getFirestore(rt.app);
        const jobRef = db.collection(COLLECTION).doc(jobId);
        const jobSnap = await jobRef.get();
        if (jobSnap.exists && jobSnap.data().uid !== grant.uid) {
          return res.status(403).json({ error: 'study_job_binding_invalid' });
        }
        if (jobSnap.exists) {
          await deleteJobTree(db, jobRef);
        }
        return res.status(204).end();
      } catch (error) {
        return res.status(401).json({
          error: String(error?.message || 'study_job_delete_failed'),
        });
      }
    },
  );

  if(startWorker){
  const workerTimer = setInterval(() => { queue()?.tick().catch(() => {}); }, 3000);
  workerTimer.unref?.();
  const timer = setInterval(() => {
    cleanupExpiredJobs().catch(() => {});
  }, 30 * 60 * 1000);
  if (typeof timer.unref === 'function') {
    timer.unref();
  }
  }
  return queue();
}

module.exports = {
  registerStudyBackgroundTranscriptionRoutes,
  constants: {
    COLLECTION,
    GRANT_SCOPE,
    MAX_SEGMENTS,
    MAX_AUDIO_BYTES,
    JOB_TTL_MS,
    MODEL,
  },
};

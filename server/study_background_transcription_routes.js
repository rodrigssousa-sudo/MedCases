'use strict';

const crypto = require('crypto');
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
    enabled: secret.length >= 32 && openAiKey.length >= 20 && apps.length > 0,
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

async function transcribeBuffer(openAiKey, body, mimeType, index) {
  const form = new FormData();
  form.append('model', MODEL);
  form.append(
    'file',
    new Blob([body], { type: mimeType || 'audio/mp4' }),
    `segment_${index}.m4a`,
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
  const segments = await jobRef.collection('segments').get();
  let batch = db.batch();
  let count = 0;
  for (const doc of segments.docs) {
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

function registerStudyBackgroundTranscriptionRoutes(app) {
  if (!app || typeof app.get !== 'function') {
    throw new Error('study_background_router_app_invalid');
  }

  app.get(
    '/api/ai/study/background-transcription/capabilities',
    (req, res) => {
      const rt = runtime();
      res.status(200).json({
        enabled: rt.enabled,
        schemaVersion: 1,
        maxSegments: MAX_SEGMENTS,
        maxSegmentBytes: MAX_AUDIO_BYTES,
        audioPersistence: false,
        transcriptCheckpoint: 'firestore-transient',
        model: MODEL,
      });
    },
  );

  app.post(
    '/api/ai/study/background-transcription/jobs',
    express.json({ limit: '32kb' }),
    async (req, res) => {
      try {
        const rt = runtime();
        if (!rt.enabled) {
          return res.status(503).json({ error: 'study_background_disabled' });
        }

        const uid = await firebaseUid(req, rt.app);
        const expectedSegments = Number(req.body?.expectedSegments);
        if (
          !Number.isInteger(expectedSegments) ||
          expectedSegments < 1 ||
          expectedSegments > MAX_SEGMENTS
        ) {
          return res.status(400).json({ error: 'expected_segments_invalid' });
        }

        const locale = req.body?.locale === 'es' ? 'es' : 'pt';
        const sourceId = String(req.body?.sourceId || '').slice(0, 160);
        const jobId = crypto.randomUUID().replace(/-/g, '');
        const now = Date.now();
        const exp = now + JOB_TTL_MS;

        const db = getFirestore(rt.app);
        const jobRef = db.collection(COLLECTION).doc(jobId);
        await jobRef.set({
          uid,
          expectedSegments,
          locale,
          sourceId,
          educationalOnly: true,
          state: 'active',
          createdAt: Timestamp.fromMillis(now),
          updatedAt: Timestamp.fromMillis(now),
          expiresAt: Timestamp.fromMillis(exp),
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
        return res.status(401).json({
          error: String(error?.message || 'study_job_create_failed'),
        });
      }
    },
  );

  app.put(
    '/api/ai/study/background-transcription/jobs/:jobId/segments/:index',
    express.raw({
      type: 'application/octet-stream',
      limit: `${MAX_AUDIO_BYTES}b`,
    }),
    async (req, res) => {
      let body = null;
      try {
        const rt = runtime();
        if (!rt.enabled) {
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
        if (
          job.uid !== grant.uid ||
          Number(job.expectedSegments) !== expected
        ) {
          return res.status(403).json({ error: 'study_job_binding_invalid' });
        }

        const segmentRef = jobRef.collection('segments').doc(String(index));
        const leaseResult = await db.runTransaction(async (tx) => {
          const snap = await tx.get(segmentRef);
          const current = snap.exists ? snap.data() : null;
          if (current?.state === 'done' && current?.transcript) {
            return { state: 'done', transcript: current.transcript };
          }

          const leaseUntilMs =
            current?.leaseUntil?.toMillis?.() || 0;
          if (current?.state === 'processing' && leaseUntilMs > Date.now()) {
            return { state: 'busy' };
          }

          tx.set(
            segmentRef,
            {
              index,
              state: 'processing',
              leaseUntil: Timestamp.fromMillis(Date.now() + LEASE_MS),
              updatedAt: Timestamp.now(),
            },
            { merge: true },
          );
          return { state: 'claimed' };
        });

        if (leaseResult.state === 'done') {
          return res.status(200).json({
            segmentIndex: index,
            transcript: leaseResult.transcript,
            idempotent: true,
          });
        }
        if (leaseResult.state === 'busy') {
          return res.status(409).json({ error: 'segment_processing' });
        }

        const mimeType = String(
          req.headers['x-medcases-audio-mime'] || 'audio/mp4',
        ).slice(0, 80);

        const transcript = await transcribeBuffer(
          rt.openAiKey,
          body,
          mimeType,
          index,
        );

        await segmentRef.set(
          {
            index,
            state: 'done',
            transcript,
            resultRef: crypto
              .createHash('sha256')
              .update(`${jobId}:${index}`)
              .digest('hex'),
            leaseUntil: null,
            completedAt: Timestamp.now(),
            updatedAt: Timestamp.now(),
          },
          { merge: true },
        );
        await jobRef.set(
          { updatedAt: Timestamp.now() },
          { merge: true },
        );

        return res.status(200).json({
          segmentIndex: index,
          transcript,
          idempotent: false,
        });
      } catch (error) {
        return res.status(502).json({
          error: String(error?.message || 'study_segment_failed'),
        });
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
        if (!rt.enabled) {
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
        if (job.uid !== grant.uid) {
          return res.status(403).json({ error: 'study_job_binding_invalid' });
        }

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
          completedSegments: transcripts.length,
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
        if (!rt.enabled) {
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

  const timer = setInterval(() => {
    cleanupExpiredJobs().catch(() => {});
  }, 30 * 60 * 1000);
  if (typeof timer.unref === 'function') {
    timer.unref();
  }
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

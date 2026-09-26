'use strict';
const crypto = require('node:crypto');
const {Timestamp} = require('firebase-admin/firestore');
const {MonthlyUsageOwner} = require('./monthly_usage_owner');
const {usageReceipt, assertUsageReservation} = require('./usage_reservation_guard');
const {classifyBinary} = require('./binary_media_classifier');
const {combineProofs, digest} = require('./audio_media_budget');
const {LogicalRecordingQueue}=require('./logical_recording_queue');
const COLLECTION = '_study_background_transcription_jobs';
const LEASE_MS = 210000;
const now = () => Timestamp.now();
const millis = value => value?.toMillis?.() || 0;
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const canonical = v => v.state === 'done' ? 'completed' : v.state === 'failed'
  ? (v.retryable === false ? 'terminal_error' : 'retryable_error') : v.state;

class TranscriptionDurableQueue {
  constructor({db, storage, transcribe, centralService=null, owner = new MonthlyUsageOwner({db}), classify = classifyBinary}) {
    Object.assign(this, {db, storage, transcribe, centralService, owner, classify});
    this.running = false;
    this.logical=new LogicalRecordingQueue({db,storage,owner,centralService});
  }
  execution(job, index) {
    const r = usageReceipt(job.usage);
    return this.db.collection('usageExecutions').doc(hash(`${r.id}:${r.attempt}:${index}`));
  }
  async aggregate(jobRef, job) {
    if(job.provider==='assemblyai'){
      const current=(await jobRef.get()).data();
      const values=(await jobRef.collection('segments').get()).docs.map(d=>d.data());
      return {values,state:current.state,completed:current.completedSegments||0,failed:current.failedSegments||0};
    }
    return this.db.runTransaction(async tx => {
    const docs = await tx.get(jobRef.collection('segments'));
    const values = docs.docs.map(d => d.data());
    const completed = values.filter(v => v.state === 'done' && v.transcript).length;
    const failed = values.filter(v => ['retryable_error', 'terminal_error', 'failed'].includes(v.state)).length;
    const state = completed === job.expectedSegments ? 'completed'
      : values.some(v => ['submitted','processing', 'queued', 'uploading'].includes(v.state)) ? 'processing'
      : failed ? (values.some(v => canonical(v) === 'terminal_error') ? 'terminal_error' : 'retryable_error') : 'queued';
    const needsCleanup = values.some(v => v.state === 'done' && (v.objectKey || !v.usageSettled || (v.providerTranscriptId&&!v.providerDeleted)));
    const workerPending = needsCleanup || values.some(v => ['submitted','processing', 'queued', 'uploading'].includes(v.state));
    tx.set(jobRef, {state, completedSegments: completed, failedSegments: failed,
      pendingSegments: Math.max(0, job.expectedSegments - completed - failed), workerPending,
      updatedAt: now(), ...(state === 'completed' ? {completedAt: now()} : {})}, {merge: true});
    return {values, state, completed, failed};
    });
  }
  async enqueue(jobRef, job, index, body, receivedAt) {
    const ref = jobRef.collection('segments').doc(String(index));
    const token = crypto.randomUUID();
    const bodyHash = hash(body);
    const result = await this.db.runTransaction(async tx => {
      const snap = await tx.get(ref);
      const root=await tx.get(jobRef);
      if(root.data()?.deleted)throw Error('LOGICAL_RECORDING_CANCELLED');
      const value = snap.exists ? snap.data() : {};
      if (value.bodyHash && value.bodyHash !== bodyHash) throw Error('SEGMENT_CONTENT_CONFLICT');
      if (value.state === 'done' && value.transcript) return {state: 'completed', transcript: value.transcript};
      if (value.providerTranscriptId && ['submitted','processing'].includes(value.state)) return {state:value.state};
      if (['uploading','queued','processing'].includes(value.state) && millis(value.leaseUntil) > Date.now()) return {state: value.state};
      const execution = await tx.get(this.execution(job, index));
      if (execution.exists || canonical(value) === 'terminal_error') return {state: 'terminal_error'};
      if ((value.attemptCount || 0) >= 3) return {state: 'terminal_error'};
      tx.set(ref, {index, state: 'uploading', uploadToken: token, bodyHash,
        createdAt: value.createdAt || now(), updatedAt: now(), lastProgressAt: now(),
        processingStartedAt: null, completedAt: null, errorCategory: null,
        attemptCount: value.attemptCount || 0, leaseUntil: Timestamp.fromMillis(Date.now() + LEASE_MS),
        timings: {requestReceivedAt: receivedAt, uploadCompleteAt: Date.now()}}, {merge: true});
      tx.set(jobRef, {workerPending: true, updatedAt: now()}, {merge: true});
      return {state: 'registered'};
    });
    if (result.state !== 'registered') return {...result, idempotent: true};
    const key = this.storage.key(jobRef.id, index, token);
    let queued = false;
    try {
      await this.storage.put(key, body);
      await this.db.runTransaction(async tx => {
        const current = await tx.get(ref);
        if (current.data()?.uploadToken !== token || current.data()?.state !== 'uploading') throw Error('UPLOAD_LEASE_LOST');
        tx.set(ref, {state: 'queued', objectKey: key, byteLength: body.length,
          updatedAt: now(), lastProgressAt: now(), leaseUntil: Timestamp.fromMillis(Date.now() + LEASE_MS),
          errorCategory: null}, {merge: true});
      });
      queued = true;
      return {state: 'queued', idempotent: false};
    } finally {
      if (!queued) {
        await this.storage.remove(key).catch(() => {});
        await this.db.runTransaction(async tx => {
          const current = await tx.get(ref);
          if (current.data()?.uploadToken === token && current.data()?.state === 'uploading') {
            tx.set(ref, {state:'retryable_error', retryable:true, errorCategory:'TEMP_STORAGE_FAILED',
              updatedAt:now(), lastProgressAt:now(), leaseUntil:null}, {merge:true});
          }
        }).catch(() => {});
      }
    }
  }
  async recover(jobRef, job, ref) {
    if(job.provider==='assemblyai')return;
    await this.db.runTransaction(async tx => {
      const snap = await tx.get(ref);
      if (!snap.exists) return;
      const value = snap.data();
      if (job.provider==='assemblyai' && value.providerTranscriptId) return;
      if (!['processing','uploading'].includes(value.state) || millis(value.leaseUntil) > Date.now()) return;
      const execution = await tx.get(this.execution(job, value.index));
      const terminal = execution.exists || (value.attemptCount || 0) >= 3;
      tx.set(ref, {state: terminal ? 'terminal_error' : value.objectKey ? 'queued' : 'retryable_error',
        retryable: !terminal, errorCategory: terminal ? 'EXECUTION_RESULT_UNAVAILABLE' : 'UPLOAD_INTERRUPTED',
        leaseUntil: null, updatedAt: now(), lastProgressAt: now()}, {merge:true});
    });
  }
  async finishCleanup(jobRef, job, ref, value) {
    // Durable transcript is already present before billing completion or deletion.
    if (!value.usageSettled) {
      await this.owner.completeExecution(job.uid, usageReceipt(job.usage), value.index);
      await ref.set({usageSettled: true}, {merge: true});
    }
    if (value.objectKey) {
      await this.storage.remove(value.objectKey);
      await ref.set({objectKey: null, audioDeletedAt: now()}, {merge:true});
    }
    if (job.provider==='assemblyai' && value.providerTranscriptId && !value.providerDeleted) {
      await this.centralService.provider(job).remove(value.providerTranscriptId);
      await ref.set({providerDeleted:true,providerDeletedAt:now(),providerAudioUrl:null}, {merge:true});
    }
  }
  async process(jobRef, job, ref) {
    await this.recover(jobRef, job, ref);
    let value = (await ref.get()).data();
    if (value?.state === 'done' && value.transcript) return this.finishCleanup(jobRef, job, ref, value);
    if (job.provider==='assemblyai' && value?.providerTranscriptId && ['submitted','processing'].includes(value.state)) {
      if (!this.centralService) throw Error('CENTRAL_SERVICE_UNAVAILABLE');
      const gotLease=await this.db.runTransaction(async tx=>{
        const snap=await tx.get(ref),v=snap.data();
        if (!['submitted','processing'].includes(v?.state)||millis(v.pollLeaseUntil)>Date.now()) return false;
        tx.set(ref,{pollLeaseUntil:Timestamp.fromMillis(Date.now()+45000)},{merge:true});return true;
      });
      if (!gotLease) return;
      try {
        const result=await this.centralService.advance({job,ref,readAudio:()=>this.storage.get(value.objectKey)});
        if(result.state==='done') await this.finishCleanup(jobRef,job,ref,result);
      } finally {await ref.set({pollLeaseUntil:null},{merge:true});}
      return;
    }
    const token = crypto.randomUUID();
    const claimed = await this.db.runTransaction(async tx => {
      const snap = await tx.get(ref);
      const v = snap.data();
      if (!v || v.state !== 'queued' || !v.objectKey) return false;
      tx.set(ref, {state:'processing', workerToken:token, attemptCount:(v.attemptCount || 0)+1,
        processingStartedAt:now(), lastProgressAt:now(), updatedAt:now(),
        leaseUntil:Timestamp.fromMillis(Date.now()+LEASE_MS)}, {merge:true});
      return true;
    });
    if (!claimed) return;
    let body, dispatched = false, durable = false;
    try {
      value = (await ref.get()).data();
      body = await this.storage.get(value.objectKey);
      if (hash(body) !== value.bodyHash) throw Error('AUDIO_TYPE_INVALID');
      const binary = await this.classify(body);
      if (binary.classification !== 'SUPPORTED_AUDIO') throw Error('AUDIO_TYPE_INVALID');
      await assertUsageReservation(this.db, job.uid, job.usage);
      const media = combineProofs([binary.audioProof], digest(JSON.stringify({jobId:jobRef.id,index:value.index,mimeType:binary.mimeType})));
      const claim = await this.owner.claimExecution(job.uid, usageReceipt(job.usage), value.index, media);
      if (!claim.claimed) throw Error('EXECUTION_RESULT_UNAVAILABLE');
      dispatched = true;
      if (job.provider==='assemblyai') {
        if (!this.centralService) throw Error('CENTRAL_SERVICE_UNAVAILABLE');
        await this.centralService.advance({job,ref,readAudio:async()=>Buffer.from(body)});
        return;
      }
      const providerStart = Date.now();
      await ref.set({providerStage:'dispatching', 'timings':{...value.timings, providerCallStart:providerStart}, lastProgressAt:now()}, {merge:true});
      const transcript = await this.transcribe(body, binary.mimeType, value.index, binary);
      if (typeof transcript !== 'string' || !transcript.trim()) throw Error('PROVIDER_EMPTY_RESULT');
      const providerEnd = Date.now(), persistStart = Date.now();
      // Retry persistence, never provider dispatch. A lost response cannot duplicate billing.
      for (let attempt=0; attempt<5; attempt++) {
        try {
          await ref.set({state:'done', transcript:transcript.trim(), resultRef:hash(`${jobRef.id}:${value.index}`),
            completedAt:now(), updatedAt:now(), lastProgressAt:now(), leaseUntil:null,
            providerStage:'result_persisted', errorCategory:null, retryable:false,
            timings:{...value.timings, providerCallStart:providerStart, providerCallEnd:providerEnd, resultPersistStart:persistStart}}, {merge:true});
          durable = true;
          break;
        } catch (error) { if (attempt === 4) throw error; await sleep(250 * 2**attempt); }
      }
      await ref.set({resultPersistEnd:now()}, {merge:true});
      await this.finishCleanup(jobRef, job, ref, (await ref.get()).data());
    } catch (error) {
      if (!durable) {
        const unsafe = dispatched || /EXECUTION_|AUDIO_TYPE_|MEDIA_|RESERVATION_|SERVER_QUOTA_/.test(error.message || '');
        const category = /^openai_transcription_[0-9]{3}$/.test(error.message || '')
          ? error.message.toUpperCase() : unsafe ? 'EXECUTION_RESULT_UNAVAILABLE' : 'TEMP_STORAGE_FAILED';
        await ref.set({state:unsafe ? 'terminal_error':'retryable_error', retryable:!unsafe,
          errorCategory:category, updatedAt:now(), lastProgressAt:now(), leaseUntil:null}, {merge:true});
        if (dispatched) await this.owner.completeExecution(job.uid, usageReceipt(job.usage), value.index).catch(() => {});
      }
      // No raw exceptions, identifiers, transcripts, or audio in logs.
    } finally { if (body) body.fill(0); }
  }
  async tick() {
    if (this.running) return;
    this.running = true;
    try {
      const jobs = await this.db.collection(COLLECTION).where('workerPending','==',true).limit(100).get();
      const work = [];
      for (const doc of jobs.docs) {
        const job = doc.data();
        if(job.provider==='assemblyai'){
          work.push(()=>this.logical.process(doc.ref,job));continue;
        }
        if (millis(job.expiresAt) <= Date.now()) continue;
        const segments = await doc.ref.collection('segments').get();
        for (const segment of segments.docs) work.push(() => this.process(doc.ref, job, segment.ref));
      }
      // Independent segments, bounded memory/provider concurrency.
      let cursor = 0;
      const slots=jobs.docs.some(doc=>doc.data().provider==='assemblyai')?[0]:[0,1];
      await Promise.all(slots.map(async () => {
        while (cursor < work.length) { const next = work[cursor++]; await next().catch(() => {}); }
      }));
      for (const doc of jobs.docs) await this.aggregate(doc.ref, doc.data()).catch(() => {});
    } finally { this.running = false; }
  }
}
module.exports = {TranscriptionDurableQueue, canonical};

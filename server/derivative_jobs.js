'use strict';

const {randomUUID} = require('node:crypto');
const {DerivativeError, TranscriptChunker, identities, hash, validateInput, isCompleteResult} = require('./derivative_contract');

// Store contract: transaction(key, fn) serializes updates and returns fn's value.
// Provider calls must NEVER run inside the transaction callback (Firestore retries it).
class DerivativeJobs {
  constructor({store, engine, maxChunkTokens = 12000, maxDirectBytes = 96000}) {
    Object.assign(this, {store, engine, maxChunkTokens, maxDirectBytes});
  }

  async create(input) {
    const ids = identities(input);
    await this.store.transaction(ids.operationKey, async tx => {
      const previous = await tx.read();
      if (previous) {
        if (previous.cacheKey !== ids.cacheKey) throw new DerivativeError('operation_conflict');
        return;
      }
      await tx.write({...ids, ownerUid: input.ownerUid, sourceId: input.sourceId,
        operationId: input.operationId, transcriptHash: input.transcriptHash,
        derivativeType: input.derivativeType, promptVersion: input.promptVersion,
        locale: input.locale, status: 'PENDING', checkpoints: {}, result: null, errorCode: null});
    });
    return ids.operationKey;
  }

  async read(ownerUid, operationKey) {
    let job = await this.store.transaction(operationKey, async tx => {
      const current = await tx.read();
      if (!current || current.ownerUid !== ownerUid) throw new DerivativeError('not_found');
      return current;
    });
    // Another operation can finish the same cached derivative while this caller
    // is waiting. Readback must converge without starting another provider call.
    if (job.status !== 'COMPLETED') {
      const cached = await this.store.getCache(job.cacheKey);
      if (cached && isCompleteResult(job.derivativeType, cached.structuredResult)) {
        await this.update(operationKey, current => ({...current, status:'COMPLETED', result:cached, errorCode:null}));
        job = {...job, status:'COMPLETED', result:cached, errorCode:null};
      }
    }
    // Never expose checkpoint payloads or source text from the status endpoint.
    return {operationId: job.operationId, sourceId: job.sourceId, derivativeType: job.derivativeType,
      status: job.status, errorCode: job.errorCode, result: job.result};
  }

  async run(input) {
    const contract = validateInput(input);
    const {operationKey, cacheKey} = identities(input);
    await this.create(input);
    const cached = await this.store.getCache(cacheKey);
    if (cached && isCompleteResult(input.derivativeType, cached.structuredResult)) {
      await this.update(operationKey, job => ({...job, status: 'COMPLETED', result: cached, errorCode: null}));
      return cached;
    }
    // The cache-scoped lease also prevents two different operation IDs from billing
    // the same derivative concurrently. It must persist across process restarts.
    const lease = randomUUID();
    if (!await this.store.claim(cacheKey, lease)) throw new DerivativeError('operation_in_progress', true);
    let release = true;
    try {
      await this.update(operationKey, job => ({...job, status: 'PROCESSING', errorCode: null}));
      let result; let strategy;
      await this.update(operationKey, job => {
        strategy = job.strategy || (Buffer.byteLength(input.rawTranscript) <= this.maxDirectBytes ? 'DIRECT' : 'CHUNKED');
        return {...job, strategy, chunkingTrigger: job.chunkingTrigger ||
          (strategy === 'CHUNKED' ? 'INPUT_LIMIT_EXCEEDED' : null)};
      });
      if (strategy === 'DIRECT') {
        try { result = await this.step(operationKey, input, contract, `direct_${input.transcriptHash}`, 'direct', input.rawTranscript); }
        catch (error) {
          const triggers = {output_truncated:'DIRECT_TRUNCATION', input_limit_exceeded:'INPUT_LIMIT_EXCEEDED',
            direct_provider_limitation:'DIRECT_PROVIDER_LIMITATION'};
          if (!triggers[error.code]) throw error;
          strategy = 'CHUNKED';
          await this.update(operationKey, job => ({...job, strategy, chunkingTrigger:triggers[error.code]}));
        }
      }
      if (strategy === 'CHUNKED') {
        const chunks = TranscriptChunker.split(input.sourceId, input.rawTranscript, this.maxChunkTokens);
        const results = [];
        for (const chunk of chunks) {
          results.push(await this.step(operationKey, input, contract, `chunk_${chunk.chunkIndex}_${chunk.hash}`,
            chunks.length === 1 ? 'direct' : 'map', chunk.content));
        }
        if (results.length === 1) result = results[0];
        else if (input.derivativeType === 'ORGANIZATION') {
          // Organization must not suffer a second lossy summarization pass.
          result = {...results[0], structuredResult: {sections: results.flatMap(r => r.structuredResult.sections)}};
        } else {
          // Bounded hierarchical reduce, with durable checkpoints at every level.
          let level = 0; let current = results;
          while (current.length > 1) {
            const next = [];
            for (let i = 0; i < current.length; i += 2) {
              const batch = current.slice(i, i + 2);
              if (batch.length === 1) { next.push(batch[0]); continue; }
              const content = JSON.stringify(batch.map(r => r.structuredResult));
              // Do not silently truncate a reduction that itself exceeds safe input.
              if (Buffer.byteLength(content) > 96000) throw new DerivativeError('reduce_input_too_large');
              next.push(await this.step(operationKey, input, contract, `reduce_${level}_${i}_${hash(content)}`, 'reduce', content));
            }
            current = next; level++;
          }
          result = current[0];
        }
      }
      await this.update(operationKey, job => {
        const calls = Object.values(job.checkpoints).filter(s => s.status === 'COMPLETED').map(s => s.result).concat(job.failedAttempts || []);
        const sum = field => calls.every(r => Number.isFinite(r[field])) ? calls.reduce((n,r) => n+r[field],0) : null;
        result = {...result, inputTokens:sum('inputTokens'), outputTokens:sum('outputTokens'),
          estimatedCost:sum('estimatedCost'), providerLatencySum:sum('latency'), providerCalls:calls.length};
        return job;
      });
      // Save the result checkpoint before publishing/cache, so a save retry does
      // not call the model again. The source and STT accounting are never written.
      await this.update(operationKey, job => ({...job, status: 'PARTIAL', result}));
      await this.store.putCache(cacheKey, result);
      await this.update(operationKey, job => ({...job, status: 'COMPLETED', result, errorCode: null}));
      return result;
    } catch (error) {
      const known = error instanceof DerivativeError;
      const code = known ? error.code : 'save_failed';
      // Ambiguous delivery cannot safely be replayed: provider may have completed
      // and billed. Retain the claim until reconciliation, rather than recharging.
      release = !['generation_timeout', 'retryable_network_error', 'provider_outcome_unknown'].includes(code);
      await this.update(operationKey, job => ({...job,
        status: code === 'output_truncated' ? 'FAILED_RETRYABLE_OUTPUT_TRUNCATED' :
          known && !error.retryable ? 'FAILED_NONRETRYABLE' : 'FAILED_RETRYABLE', errorCode: code}));
      throw error;
    } finally {
      if (release) await this.store.release(cacheKey, lease);
    }
  }

  async update(key, fn) {
    return this.store.transaction(key, async tx => {
      const current = await tx.read();
      if (!current) throw new DerivativeError('not_found');
      return tx.write(fn(current));
    });
  }

  async step(key, input, contract, stepKey, stage, content) {
    let saved;
    await this.update(key, job => {
      saved = job.checkpoints[stepKey];
      if (saved?.status === 'COMPLETED') return job;
      if (saved?.status === 'SENT') throw new DerivativeError('provider_outcome_unknown');
      return {...job, checkpoints: {...job.checkpoints, [stepKey]: {status: 'SENT'}}};
    });
    if (saved?.status === 'COMPLETED') {
      if (!isCompleteResult(input.derivativeType, saved.result.structuredResult)) throw new DerivativeError('invalid_checkpoint');
      return saved.result;
    }
    let result;
    try { result = await this.engine.generate(input, {stage, content}); }
    catch (error) {
      if (error instanceof DerivativeError && !['generation_timeout', 'retryable_network_error'].includes(error.code)) {
        await this.update(key, job => ({...job, failedAttempts: [...(job.failedAttempts || []),
          {stepKey, errorCode: error.code, ...error.metadata}], checkpoints: {...job.checkpoints,
          [stepKey]: {status: 'FAILED', errorCode: error.code}}}));
      }
      throw error;
    }
    await this.update(key, job => ({...job, status: 'PARTIAL', checkpoints: {...job.checkpoints,
      [stepKey]: {status: 'COMPLETED', result}}}));
    return result;
  }
}

module.exports = {DerivativeJobs};

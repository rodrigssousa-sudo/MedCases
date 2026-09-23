'use strict';
const {Agent} = require('node:https');
const {S3Client, GetObjectCommand} = require('@aws-sdk/client-s3');
const {ClinicalContentRepository, ContentRepositoryError, MAX_BYTES, validateLogicalPath, readBounded} = require('./clinical_content_repository');

function configuration(env) {
  const endpoint = env.MEDCASES_CLINICAL_CONTENT_S3_ENDPOINT;
  const region = env.MEDCASES_CLINICAL_CONTENT_S3_REGION;
  const bucket = env.MEDCASES_CLINICAL_CONTENT_S3_BUCKET;
  const prefix = env.MEDCASES_CLINICAL_CONTENT_S3_PREFIX;
  const url = new URL(endpoint);
  if (typeof endpoint !== 'string' || endpoint !== endpoint.trim() ||
      !/^https:\/\/[A-Za-z0-9.-]+(?::[0-9]+)?\/?$/.test(endpoint) ||
      url.protocol !== 'https:' || url.username || url.password || url.search || url.hash || url.pathname !== '/' ||
      typeof region !== 'string' || !/^[a-z][a-z0-9-]{0,62}$/.test(region) ||
      typeof bucket !== 'string' || !/^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$/.test(bucket) ||
      bucket.endsWith('--x-s3') || bucket.endsWith('-s3alias') || bucket.endsWith('.mrap') ||
      bucket.includes('..') || /\.-|-\./.test(bucket) || /^\d+\.\d+\.\d+\.\d+$/.test(bucket) ||
      typeof prefix !== 'string' || prefix.length > 512 || !/^[A-Za-z0-9_-]+(?:\/[A-Za-z0-9_-]+)*$/.test(prefix)) {
    throw new ContentRepositoryError('NOT_CONFIGURED');
  }
  return {endpoint: url.origin, region, bucket, prefix};
}

class ObjectStorageClinicalContentRepository extends ClinicalContentRepository {
  constructor(env, {requestHandler, timeoutMs = 10000, maxConcurrent = 4} = {}) {
    super();
    this.config = configuration(env);
    if (!Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 10000 ||
        !Number.isInteger(maxConcurrent) || maxConcurrent < 1 || maxConcurrent > 4) throw new ContentRepositoryError('NOT_CONFIGURED');
    this.timeoutMs = timeoutMs; this.maxConcurrent = maxConcurrent; this.active = 0;
    // Explicit standard secret environment provider: no metadata, profiles or remote credential discovery.
    const credentials = () => {
      if (!env.AWS_ACCESS_KEY_ID || !env.AWS_SECRET_ACCESS_KEY) throw new ContentRepositoryError('NOT_CONFIGURED');
      return {accessKeyId: env.AWS_ACCESS_KEY_ID, secretAccessKey: env.AWS_SECRET_ACCESS_KEY,
        ...(env.AWS_SESSION_TOKEN ? {sessionToken: env.AWS_SESSION_TOKEN} : {})};
    };
    credentials();
    this.client = new S3Client({endpoint: this.config.endpoint, region: this.config.region,
      credentials, forcePathStyle: true, followRegionRedirects: false, maxAttempts: 1,
      disableS3ExpressSessionAuth: true,
      responseChecksumValidation: 'WHEN_REQUIRED',
      requestHandler: requestHandler || {connectionTimeout: 3000, requestTimeout: timeoutMs,
        httpsAgent: new Agent({keepAlive: true, maxSockets: maxConcurrent})}});
    // Runs inside the SDK deserializer: never parse an unbounded S3 XML error body.
    this.client.middlewareStack.add((next) => async (args) => {
      const result = await next(args);
      const response = result.response;
      if (response.statusCode !== 200) {
        response.body?.destroy?.(); throw new ContentRepositoryError();
      }
      const raw = response.headers['content-length'];
      if (raw !== undefined && (!/^\d+$/.test(raw) || !Number.isSafeInteger(Number(raw)))) {
        response.body?.destroy?.(); throw new ContentRepositoryError();
      }
      if (Number(raw) > MAX_BYTES) {
        response.body?.destroy?.(); throw new ContentRepositoryError('PAYLOAD_LIMIT');
      }
      return result;
    }, {step: 'deserialize', priority: 'low', name: 'boundedClinicalResponse'});
  }
  async readObject(logicalPath, {signal} = {}) {
    validateLogicalPath(logicalPath);
    if (signal?.aborted || this.active >= this.maxConcurrent) throw new ContentRepositoryError();
    this.active++;
    const controller = new AbortController();
    let body, timer, rejectAbort;
    const aborted = new Promise((_, reject) => { rejectAbort = reject; });
    const cancel = () => {
      controller.abort(); body?.destroy?.(); rejectAbort(new ContentRepositoryError());
    };
    signal?.addEventListener('abort', cancel, {once: true});
    timer = setTimeout(cancel, this.timeoutMs);
    const operation = (async () => {
      const result = await this.client.send(new GetObjectCommand({Bucket: this.config.bucket,
        Key: this.config.prefix + '/' + logicalPath}), {abortSignal: controller.signal});
      body = result.Body;
      if (controller.signal.aborted) { body?.destroy?.(); throw new ContentRepositoryError(); }
      return readBounded(body, result.ContentLength);
    })();
    // Retain the slot until transport settles, even if a broken transport ignores abort.
    operation.then(() => { this.active--; }, () => { this.active--; });
    try { return await Promise.race([operation, aborted]); }
    catch (error) {
      if (error instanceof ContentRepositoryError) throw error;
      throw new ContentRepositoryError();
    } finally {
      clearTimeout(timer); signal?.removeEventListener('abort', cancel);
      controller.abort(); body?.destroy?.();
    }
  }
  close() { this.client.destroy(); }
}
module.exports = {ObjectStorageClinicalContentRepository, configuration};

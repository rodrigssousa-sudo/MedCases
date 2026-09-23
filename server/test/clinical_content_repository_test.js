'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {Readable, PassThrough} = require('node:stream');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const {MAX_BYTES, createClinicalContentRepository, ContentRepositoryError} = require('../clinical_content_repository');
const {FilesystemClinicalContentRepository} = require('../filesystem_clinical_content_repository');
const {ObjectStorageClinicalContentRepository} = require('../object_storage_clinical_content_repository');
const {registerClinicalContentRoutes} = require('../clinical_content_routes');
const env = {
  MEDCASES_CLINICAL_CONTENT_BACKEND: 's3',
  MEDCASES_CLINICAL_CONTENT_S3_ENDPOINT: 'https://storage.example.invalid',
  MEDCASES_CLINICAL_CONTENT_S3_REGION: 'us-east-1',
  MEDCASES_CLINICAL_CONTENT_S3_BUCKET: 'private-test-bucket',
  MEDCASES_CLINICAL_CONTENT_S3_PREFIX: 'approved/test',
  AWS_ACCESS_KEY_ID: 'TEST_ONLY_KEY', AWS_SECRET_ACCESS_KEY: 'TEST_ONLY_SECRET',
};
function storage({bytes = Buffer.from('{}'), length = bytes.length, status = 200, body, fail, stall = false, timeoutMs = 1000} = {}) {
  const state = {calls: 0};
  const requestHandler = {handle: async (request, {abortSignal}) => {
    state.calls++; state.request = request; state.signal = abortSignal;
    if (stall) return new Promise((_, reject) => abortSignal.addEventListener('abort', () => reject(new Error('private transport')), {once: true}));
    if (fail) throw fail;
    state.body = body || Readable.from([bytes]);
    return {response: {statusCode: status, headers: length === null ? {} : {'content-length': String(length)}, body: state.body}};
  }, destroy() {}};
  const repo = new ObjectStorageClinicalContentRepository(env, {requestHandler, timeoutMs});
  return {repo, state};
}
async function route(repository, {uid = 'TECHNICAL_UID', premium = true, relative = 'manifest.json', rejectedToken = false} = {}) {
  let handlers; let reads = 0;
  registerClinicalContentRoutes({repository,
    app: {get: (...args) => { handlers = args.slice(1); }},
    authenticate: (req, res, next) => rejectedToken ? res.status(401).json({error: 'unauthorized'}) : next(),
    limiter: (req, res, next) => next(),
    db: {collection: () => ({doc: () => ({get: async () => { reads++; return {exists: true, data: () => ({plan: premium ? 'premium' : 'free'})}; }})})},
  });
  const res = {code: 200, sends: 0, headers: {}, status(code) {this.code = code; return this;},
    setHeader(k, v) {this.headers[k] = v;}, type() {return this;},
    json(value) {this.value = value; this.sends++; return this;}, send(value) {this.value = value; this.sends++; return this;}};
  const req = {auth: uid ? {uid} : null, params: {0: relative}};
  async function next(i = 0) { if (handlers[i]) return handlers[i](req, res, () => next(i + 1)); }
  await next();
  return {...res, reads};
}
const invalidPaths = ['../manifest.json', '%2e%2e/manifest.json', '%252e%252e/manifest.json',
  'https://host/manifest.json', '/manifest.json', 'snapshots\\1\\Drugs\\index.json',
  'snapshots/1/Drug_1/index.json', 'snapshots/-1/Drugs/index.json',
  'snapshots/1/Drugs/' + 'A'.repeat(64) + '.json', 'snapshots/1/Drugs/' + 'a'.repeat(63) + '.json',
  'manifest.json?x=1', 'manifest.json\n'];
for (const relative of invalidPaths) test('path denied before storage: ' + JSON.stringify(relative), async () => {
  let calls = 0;
  const result = await route({readObject: async () => { calls++; return Buffer.from('{}'); }}, {relative});
  assert.equal(result.code, 400); assert.equal(calls, 0);
  const {repo, state} = storage();
  await assert.rejects(repo.readObject(relative), {code: 'INVALID_PATH'}); assert.equal(state.calls, 0); repo.close();
});
for (const [name, options, code] of [['anonymous', {uid: ''}, 401], ['revoked token', {rejectedToken: true}, 401], ['Free', {premium: false}, 403]]) {
  test(name + ' performs zero storage operations', async () => {
    const {repo, state} = storage(); const result = await route(repo, options);
    assert.equal(result.code, code); assert.equal(state.calls, 0); if (code === 401) assert.equal(result.reads, 0); repo.close();
  });
}
for (const [field, values] of Object.entries({
  MEDCASES_CLINICAL_CONTENT_BACKEND: ['', 'S3', 'unknown'],
  MEDCASES_CLINICAL_CONTENT_S3_ENDPOINT: [undefined, 'http://x', 'https://u:p@host', 'https://host?x', 'https://host#x', 'https://host/base', 'https://host/../', 'https://host\\evil', ' https://host'],
  MEDCASES_CLINICAL_CONTENT_S3_REGION: [undefined, '', '../x', 'US EAST'],
  MEDCASES_CLINICAL_CONTENT_S3_BUCKET: [undefined, '', 'arn:bucket', '../bucket', 'a..b', '127.0.0.1'],
  MEDCASES_CLINICAL_CONTENT_S3_PREFIX: [undefined, '', '../x', '/x', 'x/', 'x//y', 'x\\y', '%2e%2e'],
  AWS_ACCESS_KEY_ID: [undefined, ''], AWS_SECRET_ACCESS_KEY: [undefined, ''],
})) for (const value of values) test('invalid configuration fail closed: ' + field + ' ' + String(value), async () => {
  const result = await route(createClinicalContentRepository({...env, [field]: value}));
  assert.equal(result.code, 503); assert.deepEqual(result.value, {error: 'NOT_CONFIGURED'});
});
test('unset backend keeps filesystem; unset root remains NOT_CONFIGURED', async () => {
  const repo = createClinicalContentRepository({}); assert.ok(repo instanceof FilesystemClinicalContentRepository);
  assert.equal((await route(repo)).value.error, 'NOT_CONFIGURED');
});
for (const [name, options, code, error] of [
  ['empty', {bytes: Buffer.alloc(0)}, 503, 'CONTENT_UNAVAILABLE'],
  ['minimum JSON', {}, 200],
  ['exactly 8 MiB', {bytes: Buffer.from('"' + ' '.repeat(MAX_BYTES - 2) + '"')}, 200],
  ['8 MiB + 1 declared', {bytes: Buffer.alloc(MAX_BYTES + 1)}, 413, 'PAYLOAD_LIMIT'],
  ['8 MiB + 1 streamed', {bytes: Buffer.alloc(MAX_BYTES + 1), length: null}, 413, 'PAYLOAD_LIMIT'],
  ['false smaller cannot bypass size', {bytes: Buffer.alloc(MAX_BYTES + 1), length: 2}, 413, 'PAYLOAD_LIMIT'],
  ['absent length', {length: null}, 200],
  ['smaller length', {length: 1}, 503, 'CONTENT_UNAVAILABLE'],
  ['larger length/truncation', {length: 3}, 503, 'CONTENT_UNAVAILABLE'],
  ['invalid length', {length: 'invalid'}, 503, 'CONTENT_UNAVAILABLE'],
  ['invalid JSON', {bytes: Buffer.from('{invalid')}, 503, 'CONTENT_UNAVAILABLE'],
]) test(name, async () => {
  const {repo, state} = storage(options);
  const result = await route(repo); assert.equal(result.code, code); assert.equal(result.sends, 1);
  if (error) assert.deepEqual(result.value, {error}); else assert.deepEqual(result.value, options.bytes || Buffer.from('{}'));
  assert.ok(state.body.destroyed); assert.ok(state.signal.aborted); repo.close();
});
test('oversized declared response never consumes stream', async () => {
  let reads = 0; const body = new Readable({read() {reads++;}});
  const {repo} = storage({body, length: MAX_BYTES + 1});
  assert.equal((await route(repo)).code, 413); assert.equal(reads, 0); assert.ok(body.destroyed); repo.close();
});
for (const status of [301, 307, 403, 404, 429, 500, 503]) test('storage status ' + status + ' sanitized without error body parsing or redirect', async () => {
  let reads = 0; const body = new Readable({read() { reads++; this.push('PRIVATE_SECRET'); }});
  const {repo, state} = storage({status, body, length: null});
  const result = await route(repo); assert.equal(result.code, 503);
  assert.deepEqual(result.value, {error: 'CONTENT_UNAVAILABLE'}); assert.equal(reads, 0);
  assert.equal(state.calls, 1); assert.ok(body.destroyed); repo.close();
});
for (const name of ['CredentialsProviderError', 'ECONNRESET']) test('sanitized ' + name, async () => {
  const fail = new Error('TEST_ONLY_SECRET https://storage.example.invalid approved/test Authorization'); fail.name = name;
  const {repo} = storage({fail}); const result = await route(repo);
  assert.deepEqual(result.value, {error: 'CONTENT_UNAVAILABLE'}); assert.equal(result.sends, 1); repo.close();
});
test('mid-stream error never sends partial JSON', async () => {
  const body = Readable.from((async function* () {yield Buffer.from('{'); throw new Error('PRIVATE_KEY');})());
  const {repo} = storage({body, length: null}); const result = await route(repo);
  assert.equal(result.sends, 1); assert.deepEqual(result.value, {error: 'CONTENT_UNAVAILABLE'}); repo.close();
});
test('timeout before response aborts transport', async () => {
  const {repo, state} = storage({stall: true, timeoutMs: 30});
  assert.equal((await route(repo)).code, 503); assert.ok(state.signal.aborted); repo.close();
});
test('timeout during stalled stream destroys stream', async () => {
  const body = new PassThrough(); body.write('{');
  const {repo, state} = storage({body, length: null, timeoutMs: 30});
  assert.equal((await route(repo)).code, 503); assert.ok(body.destroyed); assert.ok(state.signal.aborted); repo.close();
});
test('caller cancellation and pre-aborted signal', async () => {
  const {repo, state} = storage({stall: true}); const controller = new AbortController();
  const pending = repo.readObject('manifest.json', {signal: controller.signal});
  await new Promise(resolve => setTimeout(resolve, 10)); controller.abort();
  await assert.rejects(pending, {code: 'CONTENT_UNAVAILABLE'}); assert.ok(state.signal.aborted);
  await assert.rejects(repo.readObject('manifest.json', {signal: controller.signal})); assert.equal(state.calls, 1); repo.close();
});
test('concurrency is bounded with no unbounded queue', async () => {
  const {repo, state} = storage({stall: true, timeoutMs: 40});
  const pending = Array.from({length: 4}, () => repo.readObject('manifest.json').catch(e => e));
  await assert.rejects(repo.readObject('manifest.json')); await Promise.all(pending);
  assert.equal(state.calls, 4); repo.close();
});
test('real SDK serializes only fixed host/prefix and GetObject; ignores ETag and clinical hash semantics', async () => {
  const {repo, state} = storage();
  await repo.readObject('snapshots/001/Drugs/' + 'a'.repeat(64) + '.json');
  assert.equal(state.request.hostname, 'storage.example.invalid'); assert.equal(state.request.method, 'GET');
  assert.equal(state.request.path, '/private-test-bucket/approved/test/snapshots/001/Drugs/' + 'a'.repeat(64) + '.json');
  assert.ok(state.request.headers.authorization.startsWith('AWS4-HMAC-SHA256 ')); repo.close();
});
test('filesystem and S3 preserve original JSON bytes including whitespace and metadata', async () => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'storage-parity-'));
  const bytes = Buffer.from(' { "testOnly": true, "contentHash": "NOT_RAW_SHA", "publicationStatus": "REVOKED", "pt": {}, "es": {} }\n');
  const {repo} = storage({bytes});
  try {
    await fs.writeFile(path.join(root, 'manifest.json'), bytes);
    const disk = await route(new FilesystemClinicalContentRepository(root)); const object = await route(repo);
    assert.equal(disk.code, 200); assert.deepEqual(disk.value, bytes); assert.deepEqual(object.value, bytes);
    assert.equal(object.headers['Cache-Control'], 'private, no-store');
  } finally {repo.close(); await fs.rm(root, {recursive: true, force: true});}
});
test('fake repository cannot leak arbitrary error codes/messages', async () => {
  const result = await route({readObject: async () => {throw new ContentRepositoryError('SECRET_ENDPOINT');}});
  assert.deepEqual(result.value, {error: 'CONTENT_UNAVAILABLE'});
});
for (const bucket of ['private--x-s3', 'private-s3alias', 'private.mrap']) test('no implicit alternate S3 APIs: ' + bucket, async () => {
  const repo = createClinicalContentRepository({...env, MEDCASES_CLINICAL_CONTENT_S3_BUCKET: bucket});
  assert.equal((await route(repo)).value.error, 'NOT_CONFIGURED');
});
test('stream stops at first oversized chunk', async () => {
  let read = 0;
  const body = Readable.from((async function* () {
    read++; yield Buffer.alloc(MAX_BYTES);
    read++; yield Buffer.from('!');
    read++; yield Buffer.from('SHOULD_NOT_REACH_RESPONSE');
  })(), {highWaterMark: 1});
  const {repo} = storage({body, length: null});
  assert.equal((await route(repo)).code, 413); assert.ok(body.destroyed);
  // Node may prefetch one chunk; no further buffering/response is permitted.
  assert.ok(read <= 3); repo.close();
});
for (const [name, size, status] of [['exact limit', MAX_BYTES, 200], ['over limit', MAX_BYTES + 1, 413]]) test('filesystem ' + name, async () => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'storage-fs-limit-'));
  try {
    await fs.writeFile(path.join(root, 'manifest.json'), '"' + ' '.repeat(size - 2) + '"');
    assert.equal((await route(new FilesystemClinicalContentRepository(root))).code, status);
  } finally {await fs.rm(root, {recursive: true, force: true});}
});
test('client disconnect cancels repository signal', async () => {
  const {EventEmitter} = require('node:events');
  let handler, signal;
  registerClinicalContentRoutes({app: {get: (...args) => {handler = args.at(-1);}}, authenticate() {}, limiter() {},
    db: {collection: () => ({doc: () => ({get: async () => ({exists: true, data: () => ({plan: 'premium'})})})})},
    repository: {readObject: async (_, options) => {signal = options.signal; return new Promise((_, reject) => signal.addEventListener('abort', () => reject(new Error('closed'))));}},
  });
  const res = new EventEmitter(); Object.assign(res, {setHeader() {}, status() {return this;}, json() {return this;}});
  const pending = handler({auth: {uid: 'TECHNICAL'}, params: {0: 'manifest.json'}}, res);
  await new Promise(resolve => setImmediate(resolve)); res.emit('close'); await pending;
  assert.ok(signal.aborted); assert.equal(res.listenerCount('close'), 0);
});

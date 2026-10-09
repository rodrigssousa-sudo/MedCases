'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {CONTRACTS, TranscriptChunker, DerivativeError, hash, identities, validateSchema} = require('../derivative_contract');
const {AssemblyAiDerivativeEngine, FLAG} = require('../assemblyai_derivative_engine');
const {DerivativeJobs} = require('../derivative_jobs');

function sample(schema) {
  if (schema.anyOf) return sample(schema.anyOf[0]);
  if (schema.enum) return schema.enum[0];
  if (schema.type === 'object') return Object.fromEntries(Object.entries(schema.properties).map(([k,v]) => [k,sample(v)]));
  if (schema.type === 'array') return [sample(schema.items)];
  return 'Synthetic fact';
}
function input(type = 'SUMMARY', source = 'Synthetic source. No fever. Test-A 5 mg. Allergy explicitly recorded.') {
  return {ownerUid: 'test-owner', sourceId: 'test-source', rawTranscript: source,
    transcriptHash: hash(source), operationId: 'test-operation', derivativeType: type,
    promptVersion: CONTRACTS[type].version, locale: 'pt'};
}
function provider(body, status = 200) { return async () => ({ok: status === 200, status, json: async () => body}); }
function response(type = 'SUMMARY', finish = 'stop') {
  return {choices: [{finish_reason: finish, message: {content: JSON.stringify(sample(CONTRACTS[type].schema))}}],
    usage: {input_tokens: 20, output_tokens: 30}};
}
function engine(fetchImpl, enabled = true) {
  return new AssemblyAiDerivativeEngine({apiKey: 'synthetic-key', enabled,
    models: Object.fromEntries(Object.keys(CONTRACTS).map(t => [t, 'benchmark-only'])), fetchImpl});
}
// Shared durable backing simulates process recreation. Transactional exclusion is
// tested concurrently, not by mocking away the locking behavior.
class Store {
  constructor() { this.jobs = new Map(); this.cache = new Map(); this.claims = new Map(); this.queue = Promise.resolve(); }
  transaction(key, fn) {
    const task = this.queue.then(() => fn({read: async () => structuredClone(this.jobs.get(key)),
      write: async value => this.jobs.set(key, structuredClone(value))}));
    this.queue = task.catch(() => {}); return task;
  }
  async getCache(key) { return structuredClone(this.cache.get(key)); }
  async putCache(key, value) { this.cache.set(key, structuredClone(value)); }
  async claim(key, lease) { if (this.claims.has(key)) return false; this.claims.set(key, lease); return true; }
  async release(key, lease) { if (this.claims.get(key) === lease) this.claims.delete(key); }
}

for (const type of Object.keys(CONTRACTS)) {
  test(`${type}: structured result; source immutable; PT/ES cache separation`, async () => {
    const original = Object.freeze(input(type));
    const result = await engine(provider(response(type))).generate(original);
    assert.equal(result.status, 'COMPLETED');
    assert.equal(hash(original.rawTranscript), original.transcriptHash);
    assert.notEqual(identities(original).cacheKey, identities({...original, locale:'es'}).cacheKey);
    assert.ok(validateSchema(result.structuredResult, CONTRACTS[type].schema));
  });
  test(`${type}: persisted cache avoids duplicate provider call after restart`, async () => {
    let calls = 0; const store = new Store();
    const adapter = engine(async () => { calls++; return provider(response(type))(); });
    const one = new DerivativeJobs({store, engine: adapter});
    const original = input(type); const expected = await one.run(original);
    const two = new DerivativeJobs({store, engine: adapter});
    assert.deepEqual(await two.run({...original, operationId:'another-operation'}), expected);
    assert.equal(calls, 1);
    assert.equal((await two.read(original.ownerUid, identities(original).operationKey)).status, 'COMPLETED');
  });
}

test('feature flag is off unless explicitly enabled', async () => {
  assert.equal(FLAG, 'ASSEMBLYAI_DERIVATIVE_ENGINE_V2');
  await assert.rejects(engine(() => {throw Error('must not call');}, false).generate(input()), {code:'derivative_engine_disabled'});
});
for (const finish of ['length','max_tokens',null,'content_filter']) test(`reject HTTP 200 finish=${finish}`, async () => {
  await assert.rejects(engine(provider(response('SUMMARY', finish))).generate(input()),
    {code: ['length','max_tokens'].includes(finish) ? 'output_truncated' : 'invalid_output'});
});
test('AssemblyAI Claude end_turn is an observed successful stop', async () => {
  assert.equal((await engine(provider(response('SUMMARY','end_turn'))).generate(input())).status,'COMPLETED');
});
for (const code of [429,500,502,503,504]) test(`provider ${code} has diagnostic error, no hidden retry`, async () => {
  let calls=0;
  await assert.rejects(engine(async () => {calls++;return provider({},code)();}).generate(input()), {code:'provider_unavailable',retryable:true});
  assert.equal(calls,1);
});
test('timeout and network loss are distinguishable', async () => {
  await assert.rejects(engine(async () => {throw new DOMException('private','TimeoutError');}).generate(input()),{code:'generation_timeout'});
  await assert.rejects(engine(async () => {throw new TypeError('private');}).generate(input()),{code:'retryable_network_error'});
});
test('schema failures do not become completed', async () => {
  const r=response();r.choices[0].message.content='{"title":"missing sections"}';
  await assert.rejects(engine(provider(r)).generate(input()),{code:'invalid_output'});
  r.choices[0].message.content='broken';
  await assert.rejects(engine(provider(r)).generate(input()),{code:'invalid_output'});
});
test('valid JSON with empty sections is not a completed derivative', async () => {
  const r=response();r.choices[0].message.content=JSON.stringify({title:'Empty',sections:[]});
  await assert.rejects(engine(provider(r)).generate(input()),{code:'invalid_output'});
});
test('chunks preserve every character, offsets, hashes and UTF-8 budget', () => {
  const source=('PT: nega febre. ES: niega fiebre. 🌍\n').repeat(1000);
  const chunks=TranscriptChunker.split('source',source,256);
  assert.equal(chunks.map(c=>c.content).join(''),source);
  for (const c of chunks) {
    assert.equal(source.slice(c.startOffset,c.endOffset),c.content);
    assert.equal(hash(c.content),c.hash); assert.ok(c.estimatedTokens<=256); assert.ok(c.content.isWellFormed());
  }
});
test('owner/hash/version/source/type conflicts do not contaminate results', async () => {
  const x=input(); const store=new Store(); const jobs=new DerivativeJobs({store,engine:engine(provider(response()))});
  await jobs.create(x);
  await assert.rejects(jobs.create({...x,rawTranscript:'changed',transcriptHash:hash('changed')}),{code:'operation_conflict'});
  await assert.rejects(jobs.read('other-owner',identities(x).operationKey),{code:'not_found'});
  assert.notEqual(identities(x).cacheKey,identities({...x,ownerUid:'other-owner'}).cacheKey);
  await assert.rejects(jobs.run({...x,transcriptHash:'wrong'}),{code:'invalid_input'});
});
test('duplicate taps serialize; independent types do not overwrite each other', async () => {
  const store=new Store();let calls=0;
  const adapter={generate:async i=>{calls++;await new Promise(r=>setTimeout(r,10));return {status:'COMPLETED',structuredResult:sample(CONTRACTS[i.derivativeType].schema)};}};
  const jobs=new DerivativeJobs({store,engine:adapter});
  const results=await Promise.allSettled([jobs.run(input()),jobs.run(input()),jobs.run(input('KEY_POINTS'))]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,2);assert.equal(calls,2);
  assert.equal(store.cache.size,2);assert.equal(store.jobs.size,2);
});
test('chunk retry keeps completed checkpoints and does not repeat successful calls', async () => {
  const store=new Store();let calls=0;let fail=true;
  const adapter={generate:async()=>{calls++;if(calls===2&&fail)throw new DerivativeError('provider_unavailable',true);
    return {status:'COMPLETED',structuredResult:sample(CONTRACTS.ORGANIZATION.schema)};}};
  const jobs=new DerivativeJobs({store,engine:adapter,maxChunkTokens:256,maxDirectBytes:256});
  const x=input('ORGANIZATION','Synthetic fact. '.repeat(45));const count=TranscriptChunker.split(x.sourceId,x.rawTranscript,256).length;
  await assert.rejects(jobs.run(x),{code:'provider_unavailable'});fail=false;
  await new DerivativeJobs({store,engine:adapter,maxChunkTokens:256,maxDirectBytes:256}).run(x);
  assert.equal(calls,count+1);
});
test('unknown provider outcome cannot charge again on retry or new operation', async () => {
  const store=new Store();let calls=0;
  const jobs=new DerivativeJobs({store,engine:{generate:async()=>{calls++;throw new DerivativeError('generation_timeout',true);}}});
  await assert.rejects(jobs.run(input()),{code:'generation_timeout'});
  await assert.rejects(jobs.run({...input(),operationId:'retry'}),{code:'operation_in_progress'});
  assert.equal(calls,1);
});
test('cache save failure can recover from persisted result checkpoints without calling provider', async () => {
  const store=new Store();let calls=0;let fail=true;
  const write=store.putCache.bind(store);store.putCache=async(...args)=>{if(fail)throw Error('storage unavailable');return write(...args);};
  const jobs=new DerivativeJobs({store,engine:{generate:async()=>{calls++;return {status:'COMPLETED',structuredResult:sample(CONTRACTS.SUMMARY.schema)};}}});
  await assert.rejects(jobs.run(input()));fail=false;await jobs.run(input());assert.equal(calls,1);
});
test('provider request contains no audio, STT call, repair or hidden fallback', async () => {
  await engine(async(url,opts)=>{const b=JSON.parse(opts.body);assert.ok(url.endsWith('/chat/completions'));
    assert.deepEqual(b.fallback_config,{retry:false});assert.equal(b.post_processing_steps,undefined);
    assert.equal(b.audio_url,undefined);assert.equal(b.transcript_id,undefined);return provider(response())();}).generate(input());
});

test('direct first uses one request for the authorized real-source size', async () => {
  const stages=[];const store=new Store();
  const adapter=engine(provider(response()));
  const jobs=new DerivativeJobs({store,engine:{generate:(i,o)=>{stages.push(o.stage);return adapter.generate(i,o);}}});
  await jobs.run(input('SUMMARY','x'.repeat(63129)));
  assert.deepEqual(stages,['direct']);
});
test('explicit input threshold selects chunking and persists its trigger', async () => {
  const store=new Store();const i=input('SUMMARY','word '.repeat(200));
  await new DerivativeJobs({store,engine:engine(provider(response())),maxDirectBytes:256,maxChunkTokens:256}).run(i);
  assert.equal(store.jobs.get(identities(i).operationKey).chunkingTrigger,'INPUT_LIMIT_EXCEEDED');
});
test('verified direct truncation selects fallback, never publishes truncated output', async () => {
  let calls=0;const store=new Store();const i=input();
  const a=engine(async()=>provider(response('SUMMARY',++calls===1?'length':'stop'))());
  await new DerivativeJobs({store,engine:a}).run(i);
  assert.equal(calls,2);
  assert.equal(store.jobs.get(identities(i).operationKey).chunkingTrigger,'DIRECT_TRUNCATION');
});
test('truncated fallback has explicit retryable status and no cached result', async () => {
  const store=new Store();const i=input();
  await assert.rejects(new DerivativeJobs({store,engine:engine(provider(response('SUMMARY','length')))}).run(i),{code:'output_truncated'});
  assert.equal((await new DerivativeJobs({store}).read(i.ownerUid,identities(i).operationKey)).status,'FAILED_RETRYABLE_OUTPUT_TRUNCATED');
  assert.equal(store.cache.size,0);
});
test('direct timeout does not trigger chunking or another paid call', async () => {
  let calls=0;const store=new Store();const i=input();
  await assert.rejects(new DerivativeJobs({store,engine:engine(async()=>{calls++;throw new DOMException('timeout','TimeoutError');})}).run(i),{code:'generation_timeout'});
  assert.equal(calls,1);assert.equal(store.jobs.get(identities(i).operationKey).strategy,'DIRECT');
});
test('each derivative has an explicit bounded output budget', async () => {
  const {OUTPUT_BUDGETS}=require('../assemblyai_derivative_engine');
  assert.ok(new Set(Object.values(OUTPUT_BUDGETS)).size>1);
  for(const type of Object.keys(CONTRACTS)) {
    await engine(async(url,options)=>{
      assert.equal(JSON.parse(options.body).max_tokens,OUTPUT_BUDGETS[type]);
      return provider(response(type))();
    }).generate(input(type));
  }
});

test('explicit context rejection is eligible for chunk fallback; generic 400 is not', async () => {
  await assert.rejects(engine(provider({error:{code:'context_length_exceeded'}},400)).generate(input()),{code:'input_limit_exceeded'});
  await assert.rejects(engine(provider({},413)).generate(input()),{code:'input_limit_exceeded'});
  await assert.rejects(engine(provider({error:{message:'context mentioned in unrelated error'}},400)).generate(input()),{code:'provider_unavailable'});
});
test('absent patient history remains null rather than requiring invented facts', async () => {
  const r=response('ANAMNESIS');r.choices[0].message.content=JSON.stringify(Object.fromEntries(Object.keys(CONTRACTS.ANAMNESIS.schema.properties).map(k=>[k,null])));
  const output=await engine(provider(r)).generate(input('ANAMNESIS','Educational lecture without patient history.'));
  assert.ok(Object.values(output.structuredResult).every(v=>v===null));
});

test('waiting duplicate operation recovers result through status without rebilling', async () => {
  let release;let started;const entered=new Promise(r=>started=r);const wait=new Promise(r=>release=r);
  let calls=0;const store=new Store();const jobs=new DerivativeJobs({store,engine:engine(async()=>{calls++;started();await wait;return provider(response())();})});
  const i=input();const running=jobs.run(i);await entered;
  const duplicate={...i,operationId:'second-tap'};
  await assert.rejects(jobs.run(duplicate),{code:'operation_in_progress'});
  release();await running;
  assert.equal((await jobs.read(i.ownerUid,identities(duplicate).operationKey)).status,'COMPLETED');
  assert.equal(calls,1);
});

test('rejected paid output preserves usage metadata without clinical content', async () => {
  let failure;
  try {await engine(provider(response('SUMMARY','length'))).generate(input());} catch(e) {failure=e;}
  assert.equal(failure.metadata.inputTokens,20);assert.equal(failure.metadata.outputTokens,30);
  assert.equal(JSON.stringify(failure.metadata).includes('Synthetic fact'),false);
});
test('fallback usage includes rejected direct output instead of claiming it was free', async () => {
  let calls=0;const store=new Store();const i=input();
  const result=await new DerivativeJobs({store,engine:engine(async()=>provider(response('SUMMARY',++calls===1?'length':'stop'))())}).run(i);
  assert.equal(result.providerCalls,2);assert.equal(result.inputTokens,40);assert.equal(result.outputTokens,60);
  assert.equal(result.estimatedCost,null);
});

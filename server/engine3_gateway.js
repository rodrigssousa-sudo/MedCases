'use strict';
const { createHash } = require('node:crypto');
const { Readable, Transform } = require('node:stream');
const { pipeline } = require('node:stream/promises');
const { JWT } = require('google-auth-library');
const PROJECT = 'medcases-r15-hml-261014';
const GATEWAY_IDENTITY = `medcases-gateway-hml@${PROJECT}.iam.gserviceaccount.com`;
const AUDIENCE = 'https://medcases-clinical-engine3-hml-sj4rlw5deq-uc.a.run.app';
const TARGET = 'https://e3-polish---medcases-clinical-engine3-hml-sj4rlw5deq-uc.a.run.app/stream';
const ROUTE = '/api/engine3/stream';
const ALLOWED_ORIGINS = new Set(['http://127.0.0.1:8895']);
const hash = value => createHash('sha256').update(value).digest('hex');

function configuration(env) {
  if (env.ENGINE3_GATEWAY_ENABLED !== 'true') return { enabled: false };
  const origins = (env.ENGINE3_HML_ORIGINS || '').split(',').map(x => x.trim());
  if (env.FIREBASE_PROJECT_ID !== PROJECT || !origins.length ||
      origins.some(x => !ALLOWED_ORIGINS.has(x))) throw Error('ENGINE3_HML_CONFIGURATION');
  // No client-selected URL, service, audience or impersonation target.
  return { enabled: true, origins: new Set(origins), nativeIos: env.ENGINE3_HML_NATIVE_IOS_ENABLED === 'true' };
}

function runtimeIdTokenProvider(env) {
  const credentials = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON || '{}');
  if (credentials.project_id !== PROJECT || credentials.client_email !== GATEWAY_IDENTITY ||
      credentials.type !== 'service_account' || !credentials.private_key) throw Error('ENGINE3_GATEWAY_IDENTITY');
  // Reuse the gateway's existing server-only identity. Never accept user credentials
  // or ADC fallback to an operator. No key is created/exported by this integration.
  const jwt = new JWT({ email: credentials.client_email, key: credentials.private_key,
    keyId: credentials.private_key_id });
  const request = jwt.transporter.request.bind(jwt.transporter);
  jwt.transporter.request = options => request({ ...options, retry: false,
    retryConfig: { retry: 0 }, timeout: 10000 });
  return async () => jwt.fetchIdToken(AUDIENCE);
}
function checkInvokerToken(token) {
  const parts = typeof token === 'string' ? token.split('.') : [];
  if (parts.length !== 3) throw Error('ENGINE3_INVOKER_TOKEN');
  const d = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
  // Token comes only from Google's HTTPS token exchange, not an incoming header.
  if (d.aud !== AUDIENCE || !['https://accounts.google.com','accounts.google.com'].includes(d.iss) ||
      d.email !== GATEWAY_IDENTITY || !(d.exp > Date.now()/1000 + 30)) throw Error('ENGINE3_INVOKER_TOKEN');
}
function sendError(res, status, error, requestId, validation) {
  if (res.destroyed || res.headersSent) return;
  res.statusCode = status;res.setHeader('Content-Type','application/json');
  res.setHeader('Cache-Control','no-store');
  res.end(JSON.stringify({ error, ...(requestId ? {requestId} : {}), ...(validation ? {validation} : {}) }));
}
async function readBounded(body, limit) {
  let size=0;const chunks=[];
  for await(const chunk of body) { const bytes=Buffer.from(chunk);size+=bytes.length;
    if(size>limit)throw Error('ENGINE3_PAYLOAD_SIZE');chunks.push(bytes); }
  return Buffer.concat(chunks);
}
function requestBody(b, headerId) {
  const fields=['requestId','question','language','mode','use','responseCapabilities'];
  if (!b || typeof b!=='object' || Object.keys(b).some(k=>!fields.includes(k)) ||
      typeof b.requestId!=='string' || !/^[a-zA-Z0-9_-]{1,100}$/.test(b.requestId) || typeof b.question!=='string' ||
      !b.question.trim() || b.question.length>4000 || !['pt','es'].includes(b.language) ||
      b.mode!=='plantao' || !['general_education','individual_case'].includes(b.use) ||
      (headerId && headerId!==b.requestId) ||
      (Object.hasOwn(b,'responseCapabilities') && (!Array.isArray(b.responseCapabilities) || b.responseCapabilities.length!==1 || b.responseCapabilities[0]!=='DRUG_RECORD_RESPONSE_V1'))) throw Error('ENGINE3_REQUEST_INVALID');
  return b;
}

function createEngine3Gateway({ env=process.env, verifyFirebase, getInvokerToken,
    fetchUpstream=fetch, log=()=>{}, timeoutMs=130000 }={}) {
  const config=configuration(env);
  if(!config.enabled) return (_req,res)=>sendError(res,404,'NOT_FOUND');
  if(typeof verifyFirebase!=='function')throw Error('ENGINE3_FIREBASE_VERIFIER_REQUIRED');
  const tokenProvider=getInvokerToken || runtimeIdTokenProvider(env);
  const seen=new Map();
  return async (req,res) => {
    if((req.originalUrl || req.url)!==ROUTE) return sendError(res,404,'NOT_FOUND');
    const origin=req.headers.origin;
    res.setHeader('Vary','Origin');
    // Transport marker is NOT identity or authorization: Firebase and invoker checks still run.
    const nativeIos = origin === undefined && config.nativeIos &&
      req.headers['x-medcases-client'] === 'ios-hml' && req.method === 'POST';
    if(!nativeIos && !config.origins.has(origin))return sendError(res,403,'ENGINE3_ORIGIN_DENIED');
    if(!nativeIos)res.setHeader('Access-Control-Allow-Origin',origin);
    res.setHeader('Access-Control-Expose-Headers','X-Request-Id');
    if(req.method==='OPTIONS') {
      const headers=(req.headers['access-control-request-headers']||'').toLowerCase().split(',').map(x=>x.trim()).filter(Boolean);
      if(req.headers['access-control-request-method']!=='POST' || headers.some(x=>!['authorization','content-type','x-request-id'].includes(x)))return sendError(res,403,'ENGINE3_PREFLIGHT_DENIED');
      res.setHeader('Access-Control-Allow-Methods','POST, OPTIONS');
      res.setHeader('Access-Control-Allow-Headers','Authorization, Content-Type, X-Request-Id');
      res.setHeader('Access-Control-Max-Age','300');res.statusCode=204;return res.end();
    }
    if(req.method!=='POST')return sendError(res,405,'ENGINE3_METHOD_DENIED');
    if(!(req.headers['content-type']||'').toLowerCase().startsWith('application/json'))return sendError(res,415,'ENGINE3_CONTENT_TYPE');
    const authorization=req.headers.authorization || '';
    if(!/^Bearer [^\s]+$/.test(authorization))return sendError(res,401,'AUTH_INVALID');
    const abort=new AbortController();let requestId,stage='AUTH';let completed=false;
    const onClose=()=>{if(!completed && !res.writableFinished)abort.abort();};
    req.on('aborted',onClose);res.on('close',onClose);
    const timer=setTimeout(()=>{abort.abort();if(!res.headersSent)sendError(res,504,'ENGINE3_TIMEOUT',requestId);else res.destroy();},timeoutMs);
    timer.unref();
    try {
      const decoded=await verifyFirebase(authorization.slice(7),true);
      if(typeof decoded?.uid!=='string' || !decoded.uid || decoded.aud!==PROJECT || decoded.iss!==`https://securetoken.google.com/${PROJECT}`) {
        return sendError(res,401,'AUTH_INVALID');
      }
      if(abort.signal.aborted)return;
      stage='REQUEST';
      const b=requestBody(JSON.parse((await readBounded(req,16384)).toString('utf8')),req.headers['x-request-id']);
      requestId=b.requestId;res.setHeader('X-Request-Id',requestId);
      const now=Date.now();for(const [key,expires]of seen)if(expires<=now)seen.delete(key);
      const key=hash(`${decoded.uid}\0${requestId}`);
      if(seen.has(key))return sendError(res,409,'ENGINE3_DUPLICATE_REQUEST',requestId);
      if(seen.size>=4096)return sendError(res,503,'ENGINE3_ADMISSION_FULL',requestId);
      seen.set(key,now+86400000); // Local replay suppression; server transaction remains authoritative.
      stage='INVOKER';const invokerToken=await tokenProvider(AUDIENCE);checkInvokerToken(invokerToken);
      if(abort.signal.aborted)return;
      stage='UPSTREAM';
      const upstream=await fetchUpstream(TARGET,{method:'POST',redirect:'manual',signal:abort.signal,
        headers:{'Authorization':authorization,'X-Serverless-Authorization':`Bearer ${invokerToken}`,
          'Content-Type':'application/json','Accept':'text/event-stream','Accept-Encoding':'identity','X-Request-Id':requestId},
        body:JSON.stringify(b)});
      if(upstream.status!==200) {
        // Preserve status and safe engine error code, never upstream HTML/auth material.
        let code=`ENGINE3_UPSTREAM_HTTP_${upstream.status}`, validation;
        if((upstream.headers.get('content-type')||'').includes('application/json')) {
          try {const d=JSON.parse((await readBounded(upstream.body,16384)).toString('utf8'));
            if(typeof d.error==='string'&&/^[A-Z][A-Z0-9_]{0,79}$/.test(d.error))code=d.error;
            if(d.validation?.state==='BLOCKED' && d.validation.safeForDelivery===false)validation={state:'BLOCKED',safeForDelivery:false};
          } catch { /* retain safe status code */ }
        } else await upstream.body?.cancel();
        return sendError(res,upstream.status>=300&&upstream.status<400?502:upstream.status,code,requestId,validation);
      }
      if(!(upstream.headers.get('content-type')||'').startsWith('text/event-stream')||!upstream.body){await upstream.body?.cancel();return sendError(res,502,'ENGINE3_UPSTREAM_NOT_SSE',requestId);}
      stage='SSE';res.statusCode=200;
      res.setHeader('Content-Type','text/event-stream; charset=utf-8');
      res.setHeader('Cache-Control','no-cache, no-store, no-transform');
      res.setHeader('X-Accel-Buffering','no');res.flushHeaders();
      let size=0;
      const bounded=new Transform({transform(chunk,_encoding,callback){size+=chunk.length;callback(size>4*1024*1024?Error('ENGINE3_STREAM_SIZE'):null,chunk);}});
      await pipeline(Readable.fromWeb(upstream.body),bounded,res,{signal:abort.signal});
      completed=true;
    } catch (_) {
      // No tokens, source bodies, question, UID, arbitrary error strings or stack.
      try {log({stage,code:'ENGINE3_GATEWAY_FAILURE',requestHash:requestId?hash(requestId):undefined});}catch{}
      if(!res.headersSent)sendError(res,stage==='AUTH'?401:stage==='REQUEST'?400:502,
        stage==='AUTH'?'AUTH_INVALID':stage==='REQUEST'?'REQUEST_INVALID':'ENGINE3_GATEWAY_FAILURE',requestId);
      else if(!res.destroyed)res.destroy();
    } finally { clearTimeout(timer);req.removeListener('aborted',onClose);res.removeListener('close',onClose); }
  };
}
module.exports={createEngine3Gateway,runtimeIdTokenProvider,configuration,checkInvokerToken,PROJECT,GATEWAY_IDENTITY,AUDIENCE,TARGET,ROUTE};

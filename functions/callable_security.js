'use strict';
const {HttpsError} = require('firebase-functions/v2/https');
const PRODUCTION_ORIGINS = Object.freeze(['https://medcasespro.com', 'https://www.medcasespro.com']);
const LOCAL_ORIGINS = Object.freeze(['http://localhost', 'http://localhost:3000', 'http://localhost:8080', 'http://127.0.0.1']);
function callableCorsOrigins(environment = process.env.NODE_ENV) {
  return [...PRODUCTION_ORIGINS, ...(['development', 'local'].includes(environment) ? LOCAL_ORIGINS : [])];
}
// SDK onCall verifies signature/expiry, but not revocation. Verify again before
// any role/status lookup or sensitive work; never trust a payload UID/token.
async function requireCallableRevocation(request, auth) {
  const header = request.rawRequest?.headers?.authorization;
  const match = typeof header === 'string' && /^Bearer ([^\s]+)$/i.exec(header);
  if (!request.auth?.uid || !match) throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
  let verified;
  try { verified = await auth.verifyIdToken(match[1], true); }
  catch (_) { throw new HttpsError('unauthenticated', 'AUTH_INVALID'); }
  if (!verified?.uid || verified.uid !== request.auth.uid ||
      (request.auth.token?.sub && request.auth.token.sub !== verified.uid)) {
    throw new HttpsError('unauthenticated', 'AUTH_CONTEXT_MISMATCH');
  }
  return verified;
}
module.exports = {callableCorsOrigins, requireCallableRevocation};

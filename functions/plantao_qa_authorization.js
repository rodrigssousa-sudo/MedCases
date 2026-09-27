
'use strict';
// An Admin-issued, expiring claim authorizes one verified UID on one endpoint.
// It never changes the shared user approval or any entitlement/role.
function isScopedPlantaoQaAuthorized(decodedToken, endpoint, nowMs = Date.now()) {
  const uid = decodedToken && decodedToken.uid;
  const grant = decodedToken && decodedToken.medcasesQaPlantao;
  return typeof uid === 'string' && uid.length > 0 &&
    endpoint === 'plantaoProxyStream' && grant != null &&
    grant.uid === uid && grant.endpoint === 'plantaoProxyStream' &&
    grant.syntheticOnly === true && Number.isSafeInteger(grant.expiresAtMs) &&
    grant.expiresAtMs > nowMs;
}
module.exports = {isScopedPlantaoQaAuthorized};

"use strict";
const crypto = require('node:crypto');
const MAX_OFFLINE_LEASE_SECONDS = 86400;
function signOfflineEntitlement(claims, privateKey=process.env.MEDCASES_OFFLINE_ENTITLEMENT_PRIVATE_KEY,
 ttlSeconds=Number(process.env.MEDCASES_OFFLINE_ENTITLEMENT_TTL_SECONDS ?? MAX_OFFLINE_LEASE_SECONDS)) {
 if (!privateKey) return null;
 if (!Number.isSafeInteger(ttlSeconds) || ttlSeconds <= 0 || ttlSeconds > MAX_OFFLINE_LEASE_SECONDS) throw Error('INVALID_OFFLINE_TTL');
 if (!claims || typeof claims.sub !== 'string' || !claims.sub || !['free','premium'].includes(claims.tier) ||
     !Number.isSafeInteger(claims.iat) || !Number.isSafeInteger(claims.exp) || claims.exp <= claims.iat) throw Error('INVALID_OFFLINE_CLAIMS');
 const payload=Buffer.from(JSON.stringify({v:1,aud:'medcases-offline',sub:claims.sub,
   tier:claims.tier,iat:claims.iat,exp:Math.min(claims.exp,claims.iat+ttlSeconds)}));
 return payload.toString('base64url')+'.'+crypto.sign(null,payload,privateKey).toString('base64url');
}
module.exports={signOfflineEntitlement,MAX_OFFLINE_LEASE_SECONDS};

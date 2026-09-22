'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const crypto=require('node:crypto');
const {signOfflineEntitlement}=require('../offline_entitlement_lease');
test('offline signer binds UID, tier and issuer expiry; public verification rejects tampering',()=>{
  const {privateKey,publicKey}=crypto.generateKeyPairSync('ed25519');
  for(const tier of ['free','premium']) {
    const signed=signOfflineEntitlement({sub:'A',tier,iat:100,exp:180},privateKey);
    const [p,s]=signed.split('.').map(x=>Buffer.from(x,'base64url'));
    assert.equal(crypto.verify(null,p,publicKey,s),true);
    assert.deepEqual(JSON.parse(p),{v:1,aud:'medcases-offline',sub:'A',tier,iat:100,exp:180});
    assert.equal(crypto.verify(null,Buffer.from(p.toString().replace('"A"','"B"')),publicKey,s),false);
  }
  const payload=JSON.parse(Buffer.from(signOfflineEntitlement({sub:'A',tier:'premium',iat:100,exp:900},privateKey).split('.')[0],'base64url'));
  assert.equal(payload.exp,900);
});
test('missing key never creates entitlement; malformed key fails',()=>{
  assert.equal(signOfflineEntitlement({},null),null);
  assert.throws(()=>signOfflineEntitlement({sub:'A',tier:'premium',iat:1,exp:2},'invalid-key'));
});

test('24 hour absolute ceiling, configurable lower TTL and 2 hour billing expiry',()=>{
 const {privateKey}=crypto.generateKeyPairSync('ed25519');
 const claims={sub:'A',tier:'premium',iat:100,exp:100+7*86400};
 const expiry=(c,ttl)=>JSON.parse(Buffer.from(signOfflineEntitlement(c,privateKey,ttl).split('.')[0],'base64url')).exp;
 assert.equal(expiry(claims,86400),86500);
 assert.equal(expiry({...claims,exp:7300},86400),7300);
 assert.equal(expiry(claims,3600),3700);
 for(const ttl of [0,-1,86401,1.1,NaN])assert.throws(()=>expiry(claims,ttl));
});

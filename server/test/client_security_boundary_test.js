'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');const fs=require('node:fs');const path=require('node:path');
const root=path.resolve(__dirname,'../..');const read=p=>fs.readFileSync(path.join(root,p),'utf8');
test('client credential writes are disabled; global configuration uses a field projection',()=>{
 const provider=read('lib/providers/app_provider.dart'),firestore=read('lib/services/firestore_service.dart');
 assert.ok(!provider.includes("p.setString(_k('openAiKey'"));
 assert.ok(!provider.includes("p.getString(_k('openAiKey'"));
 for(const method of ['saveGeminiApiKey','saveAppAiKey','saveAiKey']) {
  const start=firestore.indexOf(`Future<void> ${method}(`);assert.ok(start>0);
  const body=firestore.slice(start,firestore.indexOf('\n  }',start));assert.ok(body.includes('PROVIDER_CREDENTIALS_SERVER_MANAGED'));
 }
 assert.equal((firestore.match(/mask.fieldPaths=geminiPaidEnabled/g)||[]).length,2);
 assert.ok(provider.includes('final bool hasRealAuth = hasAuthenticatedAiSession;'));
 assert.ok(provider.includes('uid == _currentUser?.uid'));
});
test('server CORS uses exact origins and authentication checks revoked Firebase tokens',()=>{
 const source=read('server/server.js');
 assert.ok(source.includes('allowed.includes(origin)'));
 assert.ok(!source.includes('origin.startsWith(a)'));
 assert.ok(source.includes('firebaseAuth.verifyIdToken(idToken, true)'));
 for(const header of ['X-Goog-Upload-URL','X-Goog-Upload-Offset','X-Goog-Upload-Header-Content-Length'])assert.ok(source.includes(header));
});
test('billing authority fields are protected against client create/update',()=>{
 const rules=read('firestore.rules');
 const protectedFields=rules.slice(rules.indexOf('function r20aProtectedProfileFields()'),rules.indexOf('function r20aSafeSelfCreate()'));
 const safeCreate=rules.slice(rules.indexOf('function r20aSafeSelfCreate()'),rules.indexOf('function r20aSafeSelfUpdate()'));
 for(const field of ['billingEntitlementActive','billingEntitlementId','billingEntitlementExpiresAtMs']){
  assert.ok(protectedFields.includes(field));assert.ok(safeCreate.includes(field));
 }
});

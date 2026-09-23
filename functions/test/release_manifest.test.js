'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const manifest=require('./release_test_manifest.json');
test('every Functions test is explicitly classified exactly once',()=>{
 const actual=fs.readdirSync(__dirname,{recursive:true}).filter(x=>/test\.js$/.test(x)).map(x=>'functions/test/'+x).sort();
 const entries=[...manifest.releaseFunctions,...manifest.historicalPipelineArchaeology];const listed=entries.map(x=>x.file).sort();assert.equal(new Set(listed).size,listed.length);assert.deepEqual(listed,actual);
 assert.deepEqual(manifest.releaseGroups.find(g=>g.id==='functions').files,manifest.releaseFunctions.map(x=>x.file));
 for(const x of manifest.historicalPipelineArchaeology){assert.equal(x.disposition,'HISTORICAL_NON_RELEASE');assert.ok(x.rationale.length>50);assert.ok(x.artifactReferences.length>0);}
});
test('release gate retains all required security groups and actual stream integration',()=>{
 for(const category of ['security','billing','auth','quota','email','clinical-runtime','provider','firestore','remote-control-plane'])assert.ok(manifest.categories.includes(category));
 const files=manifest.releaseGroups.flatMap(x=>x.files);
 for(const name of ['functions/test/openai_responses_stream.integration.test.js','functions/test/nodemailer_security.test.js','functions/test/shadow_handler_parity.test.js','server/test/security_auth_test.js','server/test/revenuecat_webhook_routes_test.js','server/test/monthly_usage_owner_test.js','test/testimonials_rules/security-remediation.mjs','test/security_remediation_test.dart','test/services/private_cache_web_test.dart'])assert.ok(files.includes(name),name);
 for(const x of manifest.historicalPipelineArchaeology)assert.ok(!files.includes(x.file));
});

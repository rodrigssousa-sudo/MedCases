'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {validateGuide}=require('../admin_guide_operations');
const {userProjection,projection}=require('../admin_operations');
test('entitlement display uses existing flags without granting entitlement',()=>{
 for(const [data,label] of [[{plan:'free'},'FREE'],[{plan:'premium'},'PREMIUM'],[{isPartner:true},'VIP'],[{plan:'internal'},'INTERNAL'],[{},'UNKNOWN']])assert.equal(userProjection({id:'x',data:()=>data}).entitlementLabel,label);
});
test('audit projection excludes nested credentials and clinical content',()=>{
 const p=projection({id:'x',data:()=>({actorUid:'a',beforeMetadata:{role:'user',token:'secret'},afterMetadata:{status:'approved',transcript:'secret'}})},'actorUid');assert(!JSON.stringify(p).includes('secret'));assert.equal(p.afterMetadata.status,'approved');
});
test('guide invalid body and locale rejected',()=>assert.throws(()=>validateGuide({version:1,isPublished:true,localizations:{}}),/GUIDE_LOCALE_INVALID/));
test('callable rejects unauthenticated and unsupported operations before data access',async()=>{
 const box={module:{exports:{}},require:name=>name.endsWith('/https')?{onCall:(_,fn)=>fn,HttpsError:class extends Error{constructor(code,message){super(message);this.code=code;}}}:name.includes('admin_guide')?{createAdminGuideOperations:()=>{throw Error('RUNTIME');}}:{createAdminOperations:()=>{throw Error('RUNTIME');}}};
 vm.runInNewContext(fs.readFileSync(require.resolve('../admin_operations_exports'),'utf8'),box);const f=box.module.exports({}).adminOperations;
 await assert.rejects(f({data:{}}),/UNAUTHENTICATED/);await assert.rejects(f({auth:{uid:'x'},data:{operation:'deploy'}}),/UNKNOWN_OPERATION/);
});
test('manual credit implementation remains outside phase2 module',()=>{
 const source=fs.readFileSync(require.resolve('../admin_operations'),'utf8');assert(!source.includes('baseReservedSeconds'));assert(!source.includes('grantCredit'));assert(!source.includes('revokeCredit'));
});
test('inventory handoff requires provenance and refuses clinical payload or invented status',()=>{
 const {inventoryRecord}=require('../admin_inventory_contract');const source={repository:'https://example.invalid/repository',revision:'a'.repeat(40)};
 const d=inventoryRecord('drugs',source,{canonicalId:'fixture',namePt:'Fixture',calculationAuthorized:false});assert.equal(d.status,'UNKNOWN');assert.equal(d.calculationAuthorized,false);
 assert.throws(()=>inventoryRecord('drugs',source,{canonicalId:'x',dose:100}),/METADATA_ONLY/);
 assert.throws(()=>inventoryRecord('pathologies',{}, {canonicalId:'x'}),/PROVENANCE/);
 assert.throws(()=>inventoryRecord('drugs',source,{canonicalId:'x',status:'READY'}),/INVALID_CONTENT_STATE/);
});
test('empty or unrecognized guide child cannot bypass bilingual review',()=>{
 const locale={language:'pt',title:'Fixture',summary:'Fixture',bodyBlocks:[{type:'paragraph',text:''}],references:[]};
 const data={version:1,isPublished:true,searchPrefixes:[],localizations:{pt:locale,es:{...locale,language:'es'}}};
 assert.throws(()=>validateGuide(data),/GUIDE_REVIEW_REQUIRED/);
 data.localizations.pt.bodyBlocks=[{type:'debug',text:'x'}];assert.throws(()=>validateGuide(data),/GUIDE_BLOCK_INVALID/);
});

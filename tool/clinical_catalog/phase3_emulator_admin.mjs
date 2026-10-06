import fs from 'node:fs';import assert from 'node:assert/strict';import {createRequire} from 'node:module';
import {writeDraft,activate,rollback,readback,hash} from './publication.mjs';
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8791')throw Error('EMULATOR_REQUIRED');
const require=createRequire(import.meta.url),admin=require('../../functions/node_modules/firebase-admin');
admin.initializeApp({projectId:'demo-clinical-canary'});const db=admin.firestore();
const dir=process.env.PHASE3_AUDIT_DIR;assert.ok(dir);const release=v=>JSON.parse(fs.readFileSync(`${dir}/${v}.json`));
const c=process.argv[2];
if(c==='A'){await writeDraft(db,release('R3-A'));await activate(db,'R2-A',null);}
else if(c==='draftB'){
 await writeDraft(db,release('R3-B'));assert.equal((await db.doc('app_config/clinical_content').get()).data().activeVersion,'R2-A');
 const {initializeTestEnvironment,assertFails}=await import('../../test/testimonials_rules/node_modules/@firebase/rules-unit-testing/dist/esm/index.esm.js');
 const {doc,getDoc}=await import('../../test/testimonials_rules/node_modules/firebase/firestore/dist/esm/index.esm.js');
 const env=await initializeTestEnvironment({projectId:'demo-clinical-canary',firestore:{host:'127.0.0.1',port:8791,rules:fs.readFileSync('firestore.rules','utf8')}});
 const client=env.authenticatedContext('phase3-reader').firestore();await assertFails(getDoc(doc(client,'clinical_content_versions/R3-B')));await assertFails(getDoc(doc(client,`clinical_content_versions/R3-B/chunks/${release('R3-B').manifest.chunks[0].id}`)));await env.cleanup();
 console.log('REAL_TARGET_DRAFT_INVISIBLE=PASS');
}else if(c==='B')await activate(db,'R3-B','R2-A');
else if(c==='rollback'){
 const a=hash(await readback(db,'R2-A')),b=hash(await readback(db,'R3-B'));await rollback(db,'R3-B');assert.equal(hash(await readback(db,'R2-A')),a);assert.equal(hash(await readback(db,'R3-B')),b);
}else throw Error('COMMAND');
console.log(c+'=PASS');await admin.app().delete();

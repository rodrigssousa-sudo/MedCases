'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {sourceBindingRef,assertSameJob}=require('./transcription_job_binding');
const {database}=require('./test/transaction_fixture');
const original={uid:'owner',sourceId:'recording',singleAudio:true,expectedSegments:1,attemptId:'attempt'};
test('same job permits idempotent retry and rejects source, owner, layout or attempt substitution',()=>{assert.doesNotThrow(()=>assertSameJob(original,original));for(const changed of [{uid:'other'},{sourceId:'other'},{singleAudio:false},{expectedSegments:2},{attemptId:'other'}])assert.throws(()=>assertSameJob(original,{...original,...changed}),/binding_invalid/);});
test('source binding is isolated per owner and stable across retries',()=>{const db=database();const a=sourceBindingRef(db,'a','recording');assert.equal(a.path,sourceBindingRef(db,'a','recording').path);assert.notEqual(a.path,sourceBindingRef(db,'b','recording').path);assert.throws(()=>sourceBindingRef(db,'a','../other'),/BINDING_INVALID/);});

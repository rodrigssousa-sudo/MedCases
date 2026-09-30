'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {workerFailure}=require('./transcription_worker_failure');
test('binary decoder rejection is a media failure, not unlimited generic retry',()=>{
 const r=workerFailure(Error('BINARY_INVALID'));assert.equal(r.reasonCode,'MEDIA_PROOF_FAILED');assert.equal(r.stage,'MEDIA_PROOF_CREATED');assert.equal(r.fatal,true);
});
test('storage and persistence failures expose only classified metadata',()=>{
 const error=Object.assign(Error('private payload must not persist'),{name:'AccessDenied'});
 const r=workerFailure(error);assert.equal(r.reasonCode,'UPLOAD_FAILED');assert(!JSON.stringify(r).includes('private'));
 assert.equal(workerFailure(Error('secret'),'TRANSCRIPT_PERSISTED').reasonCode,'TRANSCRIPT_PERSIST_FAILED');
});

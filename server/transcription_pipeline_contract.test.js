'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {database}=require('./test/transaction_fixture');
const {assertNewLogicalPipeline}=require('./transcription_pipeline_contract');
const id='a'.repeat(64),attempt='synthetic',usage={'x-medcases-usage-reservation':id,'x-medcases-usage-attempt':attempt};
const key=i=>crypto.createHash('sha256').update(`${id}:${attempt}:${i}`).digest('hex');
test('fresh source can create one logical job',async()=>{const db=database();await db.runTransaction(tx=>assertNewLogicalPipeline(tx,db,usage,1));});
test('real incident shape: executions zero and one prevent incompatible four-part job',async()=>{const db=database([['usageExecutions/'+key(0),{state:'completed'}],['usageExecutions/'+key(1),{state:'completed'}]]);await assert.rejects(db.runTransaction(tx=>assertNewLogicalPipeline(tx,db,usage,4)),/PIPELINE_CONFLICT/);assert.equal(db.records.size,2);});
test('in-flight prior execution also prevents double dispatch',async()=>{const db=database([['usageExecutions/'+key(0),{state:'executing'}]]);await assert.rejects(db.runTransaction(tx=>assertNewLogicalPipeline(tx,db,usage,1)),/PIPELINE_CONFLICT/);});

'use strict';
const test=require('node:test');const assert=require('node:assert/strict');
const {EvidenceModelClient}=require('../evidence_model_client');
const payload=finish=>({model:'test-model',choices:[{finish_reason:finish,message:{content:'{}'}}],usage:{input_tokens:10,output_tokens:20}});
function client(fetchImpl){return new EvidenceModelClient({apiKey:'synthetic-private-key',model:'test-model',fetchImpl,prices:{inputPerMillion:1,outputPerMillion:5}});}
const call=c=>c.complete({name:'test',schema:{type:'object',properties:{},required:[],additionalProperties:false},system:'test',data:{source:'fictitious'},maxTokens:100});
for(const finish of ['length','max_tokens','content_filter',null])test(`evidence provider rejects incomplete finish ${finish}`,async()=>{
 await assert.rejects(call(client(async()=>({ok:true,json:async()=>payload(finish)}))),{code:['length','max_tokens'].includes(finish)?'output_truncated':'invalid_output'});
});
test('evidence provider structured schema, explicit budget, no automatic retry',async()=>{
 let calls=0;const r=await call(client(async(url,options)=>{calls++;const body=JSON.parse(options.body);assert.equal(body.max_tokens,100);assert.equal(body.fallback_config.retry,false);assert.equal(body.response_format.type,'json_schema');return {ok:true,json:async()=>payload('end_turn')};}));
 assert.equal(calls,1);assert.equal(r.usage.estimatedCost,0.00011);
});
test('provider error does not expose error body or credentials by default',async()=>{
 await assert.rejects(call(client(async()=>({ok:false,status:400,json:async()=>({error:{message:'synthetic-private-key'}})}))),e=>e.metadata.httpStatus===400&&!JSON.stringify(e).includes('synthetic-private-key'));
});

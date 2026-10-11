'use strict';
const {randomUUID}=require('node:crypto');
const {performance}=require('node:perf_hooks');
const STAGES=new Set(['ROUTER_COMPLETED','PROMPT_READY','PROVIDER_REQUEST_START','PROVIDER_FIRST_TOKEN','PROVIDER_COMPLETED','RESPONSE_COMPLETED']);
class PlantaoR8Metrics {
 constructor({sink,traceId,clock=()=>performance.now()}={}) { this.clock=clock;this.start=clock();this.id=typeof traceId==='string'&&/^r8_[a-f0-9]{32}$/.test(traceId)?traceId:randomUUID();this.sink=sink;this.spans={};this.calls=[];this.closed=false; }
 mark(stage){if(!this.closed&&STAGES.has(stage)&&this.spans[stage]===undefined)this.spans[stage]=this.clock()-this.start;}
 begin(kind,model,components={}){
  if(!['classifier','answer','research'].includes(kind))throw Error('invalid_metric_kind');
  const call={kind,model,startMs:this.clock()-this.start,status:'pending',usage:null,
    componentCharacters:Object.fromEntries(['system','history','query'].map(k=>[k,Number.isSafeInteger(components[k])&&components[k]>=0?components[k]:null]))};
  this.calls.push(call);return call;
 }
 end(call,status,usage){
  if(call.status!=='pending')return;
  call.status=['completed','failed','incomplete'].includes(status)?status:'failed';
  call.durationMs=this.clock()-this.start-call.startMs;
  const number=x=>Number.isSafeInteger(x)&&x>=0?x:null;
  call.usage={source:'provider',inputTokens:number(usage?.input_tokens??usage?.promptTokenCount),outputTokens:number(usage?.output_tokens??usage?.candidatesTokenCount),cachedInputTokens:number(usage?.input_tokens_details?.cached_tokens??usage?.cachedContentTokenCount),reasoningTokens:number(usage?.output_tokens_details?.reasoning_tokens??usage?.thoughtsTokenCount)};
 }
 close(){if(this.closed)return;this.closed=true;const data={schema:1,requestId:this.id,clock:'process_monotonic_ms',spans:{...this.spans},calls:this.calls.map(call=>({...call,componentCharacters:{...call.componentCharacters},usage:call.usage?{...call.usage}:null})),modelCalls:this.calls.length,costUsd:'UNVERIFIED'};try{this.sink?.(data);}catch(_){}return data;}
}
module.exports={PlantaoR8Metrics};

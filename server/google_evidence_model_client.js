'use strict';
const {DerivativeError}=require('./derivative_contract');const {retryAfterMs}=require('./provider_limit_retry');
class GoogleEvidenceModelClient {
 constructor({apiKey,model='gemini-3.1-pro-preview',fetchImpl=fetch,timeoutMs=120000,prices=null}){Object.assign(this,{apiKey,model,fetchImpl,timeoutMs,prices,identity:'google/'+model});}
 async complete({name,schema,system,data,maxTokens}){
  if(!this.apiKey||!/^[\w.-]+$/.test(this.model))throw new DerivativeError('provider_unavailable');
  const start=performance.now();let response,payload;
  try{
   response=await this.fetchImpl(`https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent`,{method:'POST',headers:{'content-type':'application/json','x-goog-api-key':this.apiKey},signal:AbortSignal.timeout(this.timeoutMs),body:JSON.stringify({systemInstruction:{parts:[{text:system}]},contents:[{role:'user',parts:[{text:JSON.stringify(data)}]}],generationConfig:{temperature:0,maxOutputTokens:maxTokens,responseMimeType:'application/json',responseJsonSchema:schema}})});
   if(!response.ok)throw new DerivativeError(response.status===429?'RETRYABLE_PROVIDER_LIMIT':'provider_unavailable',response.status===429||response.status>=500,{httpStatus:response.status,...(response.status===429?{retryAfterMs:retryAfterMs(response.headers?.get?.('retry-after'))}:{})});
   payload=await response.json();
  }catch(e){if(e instanceof DerivativeError)throw e;throw new DerivativeError(['AbortError','TimeoutError'].includes(e.name)?'generation_timeout':'retryable_network_error',true);}
  const c=payload.candidates?.[0];const u=payload.usageMetadata??{};
  const usage={latency:performance.now()-start,inputTokens:u.promptTokenCount??null,outputTokens:u.candidatesTokenCount??null,thinkingTokens:u.thoughtsTokenCount??0,finishReason:c?.finishReason??null,estimatedCost:null};
  if(this.prices&&[usage.inputTokens,usage.outputTokens,usage.thinkingTokens].every(Number.isFinite))usage.estimatedCost=(usage.inputTokens*this.prices.inputPerMillion+(usage.outputTokens+usage.thinkingTokens)*this.prices.outputPerMillion)/1e6;
  if(c?.finishReason!=='STOP')throw new DerivativeError(c?.finishReason==='MAX_TOKENS'?'output_truncated':'invalid_output',true,usage);
  let value;try{value=JSON.parse(c.content.parts.filter(p=>p.thought!==true).map(p=>p.text??'').join(''));}catch{throw new DerivativeError('invalid_output',true,usage);}
  return {identity:'google/'+(payload.modelVersion||this.model),value,usage};
 }
}
module.exports={GoogleEvidenceModelClient};

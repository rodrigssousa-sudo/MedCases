'use strict';
const {DerivativeError}=require('./derivative_contract');
const {retryAfterMs}=require('./provider_limit_retry');
class EvidenceModelClient {
 constructor({apiKey,model,fetchImpl=fetch,timeoutMs=120000,prices=null,diagnosticMode=false}) {Object.assign(this,{apiKey,model,fetchImpl,timeoutMs,prices,diagnosticMode});}
 async complete({name,schema,system,data,maxTokens}) {
  if(!this.apiKey||!this.model)throw new DerivativeError('provider_unavailable');
  const start=performance.now();let response;let payload;
  try {
   response=await this.fetchImpl('https://llm-gateway.assemblyai.com/v1/chat/completions',{method:'POST',
    headers:{authorization:this.apiKey,'content-type':'application/json'},signal:AbortSignal.timeout(this.timeoutMs),
    body:JSON.stringify({model:this.model,temperature:0,max_tokens:maxTokens,fallback_config:{retry:false},
     messages:[{role:'system',content:system},{role:'user',content:JSON.stringify(data)}],
     response_format:{type:'json_schema',json_schema:{name,strict:true,schema}}})});
   if(!response.ok){
    let detail=null;
    if(this.diagnosticMode){try{const body=await response.json();const message=String(body?.error?.message??body?.message??'');detail=message.split(this.apiKey).join('[REDACTED]').slice(0,600);}catch{}}
    throw new DerivativeError(response.status===429?'RETRYABLE_PROVIDER_LIMIT':'provider_unavailable',response.status===429||response.status>=500,{httpStatus:response.status,...(response.status===429?{retryAfterMs:retryAfterMs(response.headers?.get?.('retry-after'))}:{}),...(detail?{diagnostic:detail}:{})});
   }
   payload=await response.json();
  }catch(e){if(e instanceof DerivativeError)throw e;throw new DerivativeError(['AbortError','TimeoutError'].includes(e.name)?'generation_timeout':'retryable_network_error',true);}
  const usage={inputTokens:payload.usage?.input_tokens??payload.usage?.prompt_tokens??null,
   outputTokens:payload.usage?.output_tokens??payload.usage?.completion_tokens??null,latency:performance.now()-start,finishReason:payload.choices?.[0]?.finish_reason??null};
  usage.estimatedCost=this.prices&&Number.isFinite(usage.inputTokens)&&Number.isFinite(usage.outputTokens)?
   (usage.inputTokens*this.prices.inputPerMillion+usage.outputTokens*this.prices.outputPerMillion)/1e6:null;
  if(!['stop','end_turn'].includes(usage.finishReason))throw new DerivativeError(['length','max_tokens'].includes(usage.finishReason)?'output_truncated':'invalid_output',true,usage);
  let value;try{value=JSON.parse(payload.choices[0].message.content);}catch{throw new DerivativeError('invalid_output',false,usage);}
  return {value,usage,identity:`assemblyai/${payload.model||this.model}`};
 }
}
module.exports={EvidenceModelClient};

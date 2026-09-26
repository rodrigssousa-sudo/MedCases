'use strict';
const {profileOptions}=require('./transcription_profiles');
class ProviderError extends Error {
  constructor(code,{httpStatus, uncertain=false, retryable=false}={}) {
    super(code);Object.assign(this,{code,httpStatus,uncertain,retryable});
  }
}
class AssemblyAiProvider {
  constructor({apiKey, fetchImpl=fetch, baseUrl='https://api.assemblyai.com'}={}) {
    if (!apiKey) throw Error('ASSEMBLYAI_NOT_CONFIGURED');
    if (!['https://api.assemblyai.com','https://api.eu.assemblyai.com'].includes(baseUrl)) throw Error('ASSEMBLYAI_ENDPOINT_INVALID');
    Object.assign(this,{apiKey,fetchImpl,baseUrl,id:'assemblyai'});
  }
  async request(path,{method='GET',body,raw=false,timeoutMs=30000}={}) {
    let response;
    try {
      response=await this.fetchImpl(this.baseUrl+path,{method,
        headers:{authorization:this.apiKey,'content-type':raw?'application/octet-stream':'application/json'},
        ...(body===undefined?{}:{body:raw?body:JSON.stringify(body)}),
        ...(raw&&body?.pipe?{duplex:'half'}:{}),
        signal:AbortSignal.timeout(timeoutMs), redirect:'error'});
    } catch (_) {
      throw new ProviderError('ASSEMBLYAI_NETWORK_UNCERTAIN',{uncertain:method==='POST',retryable:method==='GET'});
    }
    if (!response.ok) throw new ProviderError(`ASSEMBLYAI_HTTP_${response.status}`,{
      httpStatus:response.status,uncertain:method==='POST'&&response.status>=500,
      retryable:response.status===429 || (method==='GET'&&response.status>=500)});
    const value=await response.json().catch(()=>null);
    if (!value || typeof value!=='object') throw new ProviderError('ASSEMBLYAI_RESPONSE_INVALID',{uncertain:method==='POST'});
    return value;
  }
  async upload(bytes) {
    const data=await this.request('/v2/upload',{method:'POST',body:bytes,raw:true,timeoutMs:120000});
    if (typeof data.upload_url!=='string' || !data.upload_url.startsWith('https://')) throw new ProviderError('ASSEMBLYAI_UPLOAD_INVALID');
    return data.upload_url;
  }
  async submit({audioUrl,...profile}) {
    const data=await this.request('/v2/transcript',{method:'POST',body:{audio_url:audioUrl,...profileOptions(profile)}});
    if (typeof data.id!=='string' || !/^[a-zA-Z0-9_-]{1,128}$/.test(data.id)) throw new ProviderError('ASSEMBLYAI_SUBMIT_INVALID',{uncertain:true});
    return {providerTranscriptId:data.id,status:data.status};
  }
  async poll(id) {
    if (!/^[a-zA-Z0-9_-]{1,128}$/.test(id)) throw Error('PROVIDER_ID_INVALID');
    const data=await this.request(`/v2/transcript/${encodeURIComponent(id)}`);
    if (data.id!==id) throw new ProviderError('ASSEMBLYAI_ID_MISMATCH');
    if (!['queued','processing','completed','error'].includes(data.status)) throw new ProviderError('ASSEMBLYAI_STATE_INVALID');
    if (data.status!=='completed') return {status:data.status,errorCategory:data.status==='error'?'ASSEMBLYAI_TRANSCRIPTION_ERROR':null};
    if (typeof data.text!=='string' || !data.text.trim()) throw new ProviderError('ASSEMBLYAI_EMPTY_RESULT');
    const utterances=(data.utterances || []).map(v=>{
      if (!v || typeof v.speaker!=='string' || !/^[A-Za-z0-9_-]{1,32}$/.test(v.speaker) || typeof v.text!=='string' ||
        !Number.isFinite(v.start)||!Number.isFinite(v.end)||v.start<0||v.end<v.start) throw new ProviderError('ASSEMBLYAI_UTTERANCE_INVALID');
      return {speakerLabel:v.speaker,startMs:v.start,endMs:v.end,text:v.text};
    }).sort((a,b)=>a.startMs-b.startMs);
    const words=(data.words||[]).map(v=>{
      if(typeof v.text!=='string'||!Number.isFinite(v.start)||!Number.isFinite(v.end)||v.start<0||v.end<v.start)throw new ProviderError('ASSEMBLYAI_WORD_INVALID');
      return {text:v.text,startMs:v.start,endMs:v.end};
    }).sort((a,b)=>a.startMs-b.startMs);
    return {status:'completed',text:data.text,utterances,words,languageCode:data.language_code || null,
      model:data.speech_model_used || null};
  }
  async remove(id) {
    if (!/^[a-zA-Z0-9_-]{1,128}$/.test(id)) throw Error('PROVIDER_ID_INVALID');
    await this.request(`/v2/transcript/${encodeURIComponent(id)}`,{method:'DELETE'});
  }
}
// Legacy remains an explicit provider. No automatic cross-provider failover.
class LegacyTranscriptionProvider {
  constructor(transcribe) {this.id='legacy';this.transcribe=transcribe;}
}
module.exports={AssemblyAiProvider,LegacyTranscriptionProvider,ProviderError};

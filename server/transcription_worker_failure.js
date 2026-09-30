'use strict';
// Classifications are identifiers only; never persist raw SDK/provider messages.
function workerFailure(error,stage='MEDIA_PROOF_CREATED'){
 const text=String(error?.code||error?.name||'')+' '+String(error?.message||'');
 if(/BINARY_|MEDIA_|AUDIO_TYPE_|AUDIO_BINDING_|PHYSICAL_/.test(text))return {reasonCode:'MEDIA_PROOF_FAILED',stage:'MEDIA_PROOF_CREATED',fatal:true};
 if(/RESERVATION_|QUOTA_|BINDING_/.test(text))return {reasonCode:'QUOTA_RESERVATION_FAILED',stage:'QUOTA_RESERVED',fatal:true};
 if(/AccessDenied|Forbidden|NoSuchKey|NotFound/.test(text))return {reasonCode:'UPLOAD_FAILED',stage:'MEDIA_UPLOAD_COMPLETED',fatal:false};
 if(/AUDIO_ASSEMBL/.test(text))return {reasonCode:'MEDIA_ASSEMBLY_FAILED',stage:'MEDIA_PROOF_CREATED',fatal:true};
 if(stage==='TRANSCRIPT_PERSISTED')return {reasonCode:'TRANSCRIPT_PERSIST_FAILED',stage,fatal:false};
 if(stage==='ACCOUNTING_FINALIZED')return {reasonCode:'ACCOUNTING_FINALIZATION_FAILED',stage,fatal:false};
 return {reasonCode:'WORKER_FAILURE',stage,fatal:false};
}
module.exports={workerFailure};

'use strict';
const {EvidenceModelClient}=require('./evidence_model_client');
const {GoogleEvidenceModelClient}=require('./google_evidence_model_client');
const {R24StudyRuntime}=require('./derivative_r24_study_runtime');
const fallbackCertificate=require('./derivative_r24_certificates/reviewer-fallback.json');
const batchCertificate=require('./derivative_r24_certificates/batch-reviewer.json');
function createR24StudyEngine({store,policy,env=process.env}) {
 const generator=new EvidenceModelClient({apiKey:env.ASSEMBLYAI_API_KEY,model:'claude-sonnet-4-6',timeoutMs:240000});
 generator.identity='assemblyai/'+generator.model;
 const fallback=new EvidenceModelClient({apiKey:env.ASSEMBLYAI_API_KEY,model:'claude-haiku-4-5-20251001',timeoutMs:240000});
 fallback.identity='assemblyai/'+fallback.model;
 const primary=new GoogleEvidenceModelClient({apiKey:env.GEMINI_PAID_API_KEY||env.GEMINI_API_KEY||env.GOOGLE_API_KEY,timeoutMs:240000});
 return new R24StudyRuntime({store,policy,generator,primaryReviewer:primary,
  fallbackReviewer:fallback,fallbackCertificate,batchCertificate,oralReviewer:generator});
}
module.exports={createR24StudyEngine};

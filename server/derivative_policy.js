'use strict';
const {hash,DerivativeError}=require('./derivative_contract');
const CLINICAL=Object.freeze(['ANAMNESIS','EVOLUTION','ORGANIZATION']);
const STUDY=Object.freeze(['SUMMARY','VISUAL_SUMMARY','KEY_POINTS','ORAL_EXAM']);
const POLICY_VERSION='dual_profile_source_only_r21_v2';
class DerivativePolicy {
  constructor(routes={}) {this.routes=structuredClone(routes);}
  resolve({derivativeType,profile,locale,rawTranscript,knowledgeMode='SOURCE_ONLY'}) {
    const expected=CLINICAL.includes(derivativeType)?'CLINICAL_DOCUMENTATION':STUDY.includes(derivativeType)?'STUDY':null;
    if(!expected||profile&&profile!==expected||!['pt','es'].includes(locale)||typeof rawTranscript!=='string'||!rawTranscript.trim()) throw new DerivativeError('invalid_policy_input');
    // Existing Study prompts explicitly prohibit external knowledge. A caller
    // cannot silently opt into enriched material or relax the clinical policy.
    if(knowledgeMode!=='SOURCE_ONLY') throw new DerivativeError('enrichment_not_authorized');
    const transcriptLength=rawTranscript.length;
    const lengthBucket=transcriptLength<=2000?'SHORT':transcriptLength<=20000?'MEDIUM':'LONG';
    const configured=this.routes[derivativeType];
    // An explicit locale/length variant wins; no paid fallback is selected implicitly.
    const variants=Array.isArray(configured?.variants)?configured.variants:[];
    const route=variants.find(r=>(!r.locale||r.locale===locale)&&(!r.lengthBucket||r.lengthBucket===lengthBucket))??configured;
    return Object.freeze({profile:expected,derivativeType,locale,lengthBucket,transcriptLength,policyVersion:POLICY_VERSION,
      knowledgeMode,summarySubtype:derivativeType==='SUMMARY'?'SUMMARY_STUDY_SOURCE_ONLY':null,
      strategy:expected==='CLINICAL_DOCUMENTATION'?'STRICT_EXTRACTIVE':'STUDY_GENERATIVE',
      directFirst:true,chunkingFallbackOnly:true,inputBytes:Buffer.byteLength(rawTranscript),
      provider:expected==='CLINICAL_DOCUMENTATION'?'deterministic':route?.provider??null,
      model:expected==='CLINICAL_DOCUMENTATION'?null:route?.model??null,
      verifierProvider:route?.verifierProvider??null,verifierModel:route?.verifierModel??null,
      routeApproved:route?.qualityApproved===true,routeRevision:route?.revision??'unapproved'});
  }
  static cacheKey(input,policy) {
    return hash(JSON.stringify([input.ownerUid,input.transcriptHash,input.derivativeType,input.promptVersion,
      policy.profile,policy.knowledgeMode,policy.policyVersion,policy.routeRevision,policy.provider,policy.model,policy.verifierProvider,policy.verifierModel,policy.lengthBucket,input.locale]));
  }
}
module.exports={DerivativePolicy,CLINICAL,STUDY,POLICY_VERSION};

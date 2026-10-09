'use strict';
const fs=require('node:fs');
const {hash,CONTRACTS,validateSchema,isCompleteResult,DerivativeError}=require('./derivative_contract');
const {TranscriptFactLedger}=require('./transcript_fact_ledger');
const {DerivativePolicy}=require('./derivative_policy');
const {DerivativeStageRunner}=require('./derivative_stage_runner');
const {ExtractiveStudyFallback}=require('./extractive_study_fallback');
const {StudyGroundingVerifier}=require('./study_grounding_verifier');
const {StudySemanticReviewer}=require('./study_semantic_reviewer');
const {StudyBatchedSemanticReviewer}=require('./study_batched_semantic_reviewer');
const {StudyPedagogicalReviewer}=require('./study_pedagogical_reviewer');
const {StudyQualityGate}=require('./study_quality_gate');
const {OralBlueprintReview}=require('./oral_blueprint_review');
const {keyPointsFromApprovedSummary}=require('./study_summary_key_points');
const {preserveSourceTerms}=require('./study_source_term_preserver');
const {generatorPrompt}=require('./derivative_r24_study_prompt');
const {withProviderLimitRetry}=require('./provider_limit_retry');
const moduleHash=name=>hash(fs.readFileSync(require.resolve('./'+name),'utf8'));
const str={type:'string'},arr=items=>({type:'array',items}),obj=properties=>({type:'object',properties,required:Object.keys(properties),additionalProperties:false});
function candidateSchema(type){return obj({structuredResult:CONTRACTS[type].schema,
 claims:arr(obj({path:str,kind:{type:'string',enum:['SOURCE_FACT','EDUCATIONAL_TRANSFORMATION']},supportingFactIds:arr(str)})),
 questionProvenance:arr(obj({supportingFactIds:arr(str),expectedAnswerFactIds:arr(str)}))});}
class R24StudyRuntime {
 constructor({store,policy,generator,primaryReviewer,fallbackReviewer=null,fallbackCertificate=null,batchCertificate=null,oralReviewer}) {
  Object.assign(this,{store,policy,generator,primaryReviewer,fallbackReviewer,fallbackCertificate,batchCertificate,oralReviewer});
 }
 wrapped(client,input,revision){
  if(!client?.identity)throw new DerivativeError('provider_unavailable');
  return new DerivativeStageRunner({store:this.store,ownerUid:input.ownerUid,operationId:input.operationId,revision}).wrap(client);
 }
 fallbackApproved(){
  const c=this.fallbackCertificate;
  return c?.passed===true&&c.identity===this.fallbackReviewer?.identity&&
   c.semanticReviewerSha256===moduleHash('study_semantic_reviewer')&&
   c.pedagogicalReviewerSha256===moduleHash('study_pedagogical_reviewer');
 }
 async reviewWithFallback(run,input,revision){
  try {return await withProviderLimitRetry(()=>run(this.wrapped(this.primaryReviewer,input,revision)));}
  catch(e){
   const explicit=(e.code==='RETRYABLE_PROVIDER_LIMIT'&&e.metadata?.httpStatus===429)||
    (e.code==='provider_unavailable'&&e.metadata?.httpStatus===503)||e.code==='output_truncated';
   if(!explicit||!this.fallbackApproved())throw e;
   // Rebuild reviewers with the actual fallback identity. Never relabel a model.
   return run(this.wrapped(this.fallbackReviewer,input,revision));
  }
 }
 async generate(input){
  const policy=this.policy.resolve(input);
  if(policy.profile!=='STUDY'||!policy.routeApproved)throw new DerivativeError('study_route_not_approved');
  if(hash(input.rawTranscript)!==input.transcriptHash)throw new DerivativeError('source_hash_mismatch');
  const ledger=TranscriptFactLedger.extract(input.rawTranscript),start=performance.now(),type=input.derivativeType;
  if(type==='ORAL_EXAM'){
   const reviewer=this.wrapped(this.oralReviewer,input,policy.routeRevision);
   const result=await new OralBlueprintReview({semanticReviewer:reviewer,pedagogicalReviewer:reviewer})
    .generate({...input,verifiedFactLedger:ledger,difficultyTarget:'MIXED',questionCount:10});
   if(result.status!=='COMPLETED'||!result.questions.length)throw new DerivativeError('insufficient_approved_questions');
   const structuredResult={questions:result.questions.map(q=>({question:q.question,expectedAnswer:q.expectedAnswer,
    keyPoints:q.answerFacts,difficulty:q.difficulty.toLowerCase(),sourceSection:q.supportingFactIds.join(', ')}))};
   if(!isCompleteResult(type,structuredResult))throw new DerivativeError('invalid_oral_result');
   return {status:'COMPLETED',structuredResult,questionProvenance:result.questions,profile:policy.profile,
    grounding:{supported:true,ledgerHash:ledger.ledgerHash,outputHash:hash(JSON.stringify(structuredResult)),reviewVersion:result.reviewVersion},
    pedagogicalQuality:{passed:true,verdicts:result.pedagogicalVerdicts},provider:reviewer.identity,
    usage:result.usage,latency:performance.now()-start,qualityGate:'ROUTE_APPROVED'};
  }
  let candidate,generatorIdentity,usage=null;
  if(input.rawTranscript.length<=2000){
   candidate=new ExtractiveStudyFallback().generate({...input,verifiedFactLedger:ledger});generatorIdentity=candidate.generatorIdentity;
  } else if(type==='KEY_POINTS'){
   const summaryInput={...input,derivativeType:'SUMMARY'};
   const summaryPolicy=this.policy.resolve(summaryInput);
   if(!summaryPolicy.routeApproved)throw new DerivativeError('summary_dependency_not_approved');
   const cacheKey=DerivativePolicy.cacheKey(summaryInput,summaryPolicy);
   let summary=await this.store.getCache(cacheKey);
   if(summary?.qualityGate!=='ROUTE_APPROVED'||summary.grounding?.ledgerHash!==ledger.ledgerHash){
    if(!this.resolveSummary)throw new DerivativeError('summary_dependency_not_configured');
    summary=await this.resolveSummary(summaryInput);
   }
   candidate=keyPointsFromApprovedSummary({candidate:{structuredResult:summary.structuredResult,claims:summary.claims},
    grounding:summary.grounding,pedagogicalQuality:summary.pedagogicalQuality,locale:input.locale}).candidate;
   generatorIdentity='deterministic/approved_summary_template';
  } else {
   const client=this.wrapped(this.generator,input,policy.routeRevision);
   const response=await client.complete({name:'study_grounded_'+type.toLowerCase()+'_r23_long_v3',schema:candidateSchema(type),maxTokens:10000,
    system:generatorPrompt(type,input.locale),data:{RAW_TRANSCRIPT:input.rawTranscript,VERIFIED_FACT_LEDGER:ledger}});
   if(response.identity!==client.identity||!validateSchema(response.value,candidateSchema(type)))throw new DerivativeError('invalid_generation_identity_or_schema');
   candidate=response.value;generatorIdentity=response.identity;usage=response.usage;
  }
  candidate=preserveSourceTerms({rawTranscript:input.rawTranscript,derivativeType:type,candidate}).candidate;
  const batched=type==='KEY_POINTS'&&input.rawTranscript.length>2000;
  if(batched&&(this.batchCertificate?.passed!==true||this.batchCertificate.batchedReviewerSha256!==moduleHash('study_batched_semantic_reviewer')||this.batchCertificate.semanticReviewerSha256!==moduleHash('study_semantic_reviewer')))throw new DerivativeError('batch_review_not_certified');
  const grounding=await this.reviewWithFallback(client=>new StudyGroundingVerifier({identity:client.identity,
   independentCheck:ctx=>batched?new StudyBatchedSemanticReviewer(client).review(ctx):new StudySemanticReviewer(client).review(ctx)})
   .verify({rawTranscript:input.rawTranscript,ledger,derivativeType:type,locale:input.locale,candidate,generatorIdentity}),input,policy.routeRevision);
  if(!grounding.supported)throw new DerivativeError('grounding_rejected');
  const pedagogicalQuality=await this.reviewWithFallback(client=>new StudyQualityGate({identity:client.identity,
   independentCheck:ctx=>new StudyPedagogicalReviewer(client).review(ctx)})
   .verify({rawTranscript:input.rawTranscript,derivativeType:type,locale:input.locale,candidate,generatorIdentity,grounding}),input,policy.routeRevision);
  if(!pedagogicalQuality.passed)throw new DerivativeError('pedagogical_quality_rejected');
  return {status:'COMPLETED',structuredResult:candidate.structuredResult,claims:grounding.normalizedClaims,
   grounding,pedagogicalQuality,profile:policy.profile,provider:generatorIdentity,generationUsage:usage,
   latency:performance.now()-start,qualityGate:'ROUTE_APPROVED'};
 }
}
module.exports={R24StudyRuntime,candidateSchema};

'use strict';
const {hash}=require('./derivative_contract');
const METRICS=Object.freeze({
 SUMMARY:['CONCEPT_COVERAGE','READABILITY','SOURCE_ALIGNMENT'],
 KEY_POINTS:['RELEVANCE','READABILITY','SOURCE_ALIGNMENT'],
 VISUAL_SUMMARY:['STRUCTURE_QUALITY','CONCEPT_COVERAGE','RELATIONSHIP_ACCURACY','READABILITY','SOURCE_ALIGNMENT'],
 ORAL_EXAM:['QUESTION_RELEVANCE','ANSWER_CORRECTNESS','DIFFICULTY_CALIBRATION','SOURCE_ALIGNMENT','PEDAGOGICAL_VALUE'],
});
class StudyQualityGate {
 constructor({independentCheck,identity}={}){Object.assign(this,{independentCheck,identity});}
 async verify({rawTranscript,derivativeType,locale,candidate,generatorIdentity,grounding}) {
  const reject=code=>({passed:false,code});
  if(!grounding?.supported||grounding.outputHash!==hash(JSON.stringify(candidate.structuredResult)))return reject('GROUNDED_OUTPUT_REQUIRED');
  const required=METRICS[derivativeType];
  if(!required||!this.independentCheck||!this.identity||this.identity===generatorIdentity)return reject('INDEPENDENT_QUALITY_CHECK_REQUIRED');
  const review=await this.independentCheck({rawTranscript,derivativeType,locale,structuredResult:candidate.structuredResult,requiredMetrics:required});
  if(review?.verifierIdentity!==this.identity||!Array.isArray(review.metrics))return reject('INVALID_QUALITY_REVIEW');
  const seen=new Set();
  for(const m of review.metrics){
   if(!required.includes(m.name)||seen.has(m.name)||!['PASS','FAIL','UNVERIFIED'].includes(m.status))return reject('INVALID_QUALITY_METRIC');
   seen.add(m.name);
  }
  const passed=seen.size===required.length&&review.metrics.every(m=>m.status==='PASS');
  return {passed,code:passed?'PEDAGOGICAL_REVIEW_PASSED':'PEDAGOGICAL_REVIEW_NOT_PASSED',metrics:review.metrics,verifierIdentity:this.identity,usage:review.usage??null,
   limitation:'Empirical review of one candidate; does not approve a model route or replace representative corpus validation.'};
 }
}
module.exports={StudyQualityGate,METRICS};

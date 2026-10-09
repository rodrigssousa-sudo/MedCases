'use strict';
const {DerivativeError,hash}=require('./derivative_contract');
const VERSION='approved_summary_key_points_r24_v1';
function keyPointsFromApprovedSummary({candidate,grounding,pedagogicalQuality,locale}){
 if(!['pt','es'].includes(locale)||grounding?.supported!==true||pedagogicalQuality?.passed!==true||grounding.outputHash!==hash(JSON.stringify(candidate?.structuredResult)))throw new DerivativeError('approved_summary_required');
 const source=candidate.structuredResult;if(!Array.isArray(source.sections)||!source.sections.length)throw new DerivativeError('invalid_summary');
 const normalized=new Map(candidate.claims.map(c=>[c.path.replace(/^\/structuredResult(?=\/)/u,''),c]));
 const titleClaim=normalized.get('/title');if(!titleClaim)throw new DerivativeError('summary_provenance_missing');
 const points=[],claims=[];
 const segmenter=new Intl.Segmenter(locale,{granularity:'sentence'});
 for(const [i,section] of source.sections.entries()){
  const bodyClaim=normalized.get(`/sections/${i}/body`),headingClaim=normalized.get(`/sections/${i}/title`);
  if(!bodyClaim||!headingClaim)throw new DerivativeError('summary_provenance_missing');
  for(const paragraph of section.body.split(/\n+/u).filter(s=>s.trim())){
   for(const {segment} of segmenter.segment(paragraph)){
    const text=segment.trim();if(!text)continue;
    points.push(`${section.title}: ${text}`);claims.push({path:`/structuredResult/points/${points.length-1}`,kind:'EDUCATIONAL_TRANSFORMATION',supportingFactIds:[...new Set([...headingClaim.supportingFactIds,...bodyClaim.supportingFactIds])]});
   }
  }
 }
 if(!points.length)throw new DerivativeError('empty_key_points');
 return {candidate:{structuredResult:{points},claims,questionProvenance:[]},revision:VERSION,summaryHash:grounding.outputHash,generationProviderCalls:0,requiresIndependentReview:true};
}
module.exports={keyPointsFromApprovedSummary,VERSION};

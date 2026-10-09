'use strict';
// Syntax normalization only. No model-generated expression is evaluated.
function canonicalPath(path){
 if(typeof path!=='string')return path;
 if(/^\$(?:\.[A-Za-z_][A-Za-z_0-9]*|\[\d+\])+$/u.test(path))path=path.slice(1).replace(/\.([A-Za-z_][A-Za-z_0-9]*)|\[(\d+)\]/gu,(_,key,index)=>`/${key??index}`);
 return path.replace(/^\/structuredResult(?=\/)/u,'');
}
function normalizeCandidate(candidate){
 const c=structuredClone(candidate);if(!Array.isArray(c?.claims))return c;
 c.claims=c.claims.map(v=>v&&({...v,path:canonicalPath(v.path)}));
 // Headings are educational transformations. Deterministically anchor a heading
 // to its body's explicit citations, then require the independent semantic check.
 // Never fill in citations for substantive body text, answers or key points.
 const add=(path,related)=>{
  if(c.claims.some(v=>v?.path===path))return;
  const ids=[...new Set(related.flatMap(v=>Array.isArray(v?.supportingFactIds)?v.supportingFactIds:[]))];
  if(ids.length)c.claims.push({path,kind:'EDUCATIONAL_TRANSFORMATION',supportingFactIds:ids});
 };
 c.structuredResult?.sections?.forEach((s,i)=>{if(typeof s.title==='string')add(`/sections/${i}/title`,c.claims.filter(v=>v?.path===`/sections/${i}/body`));});
 if(typeof c.structuredResult?.title==='string')add('/title',c.claims.filter(v=>typeof v?.path==='string'&&v.path!=='/title'));
 return c;
}
module.exports={canonicalPath,normalizeCandidate};

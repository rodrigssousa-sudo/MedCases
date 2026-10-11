'use strict';
const {createHash}=require('node:crypto');
const SOFT_CONTEXT_BYTES=128*1024;
const MAX_TRANSPORT_BYTES=1024*1024;
const MAX_INGRESS_BYTES=8*1024*1024;
// Compact only complete JSON projections inside the versioned catalog envelope.
// Unknown/freeform material is preserved byte-for-byte. No heading heuristics.
function compactCatalog(context){
 let removed=0;
 const compacted=context.replace(/(\[CLINICAL_CATALOG_VERSION:[^\]\n]+\]\n)([\s\S]*?)(\n\[\/CLINICAL_CATALOG_VERSION\])/g,(_,start,body,end)=>{
  const seen=new Set();const kept=[];
  for(const line of body.split('\n')){
   try {
    const value=JSON.parse(line);
    if(!value||typeof value!=='object'||Array.isArray(value)){kept.push(line);continue;}
    const canonical=v=>Array.isArray(v)?v.map(canonical):v&&typeof v==='object'?Object.fromEntries(Object.keys(v).sort().map(k=>[k,canonical(v[k])])):v;
    const encoded=JSON.stringify(canonical(value));
    const hash=createHash('sha256').update(encoded).digest('hex');
    if(seen.has(hash)){removed++;continue;}
    seen.add(hash);kept.push(encoded);
   }catch(_){kept.push(line);}
  }
  return start+kept.join('\n')+end;
 });
 return {context:compacted,duplicateProjectionsRemoved:removed};
}
function preserveClinicalPayload({query,context,history}) {
 if(typeof query!=='string'||typeof context!=='string'||!Array.isArray(history))throw Error('invalid_payload');
 const originalBytes=Buffer.byteLength(JSON.stringify({query,context,history}),'utf8');
 // Permit safe exact deduplication before evaluating the model-bound payload.
 // A separate ingress bound protects CPU/memory and never truncates evidence.
 if(originalBytes>MAX_INGRESS_BYTES)throw Error('clinical_payload_too_large');
 const compact=compactCatalog(context);
 const bytes=Buffer.byteLength(JSON.stringify({query,context:compact.context,history}),'utf8');
 if(bytes>MAX_TRANSPORT_BYTES)throw Error('clinical_payload_too_large');
 return {query,context:compact.context,history,bytes,budget:{originalBytes,bytes,
  duplicateProjectionsRemoved:compact.duplicateProjectionsRemoved,
  softBudgetExceeded:bytes>SOFT_CONTEXT_BYTES,
  // Unique safety/context evidence always wins over a soft optimization target.
  policy:bytes>SOFT_CONTEXT_BYTES?'preserve_unique_evidence':'within_soft_budget'}};
}
module.exports={preserveClinicalPayload,compactCatalog,SOFT_CONTEXT_BYTES,MAX_TRANSPORT_BYTES,MAX_INGRESS_BYTES};

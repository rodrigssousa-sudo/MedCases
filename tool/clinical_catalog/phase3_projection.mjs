// Technical reference-ID normalization only. Clinical text/URLs stay identical.
import assert from 'node:assert/strict';
import {canonical} from './publication.mjs';
export function projectionForSchema(source){
 const target=structuredClone(source);
 target.references=target.references.map(r=>({...r,id:String(r.id)}));
 const restore=structuredClone(target);restore.references.forEach((r,i)=>r.id=source.references[i].id);
 assert.equal(canonical(restore),canonical(source));
 return target;
}

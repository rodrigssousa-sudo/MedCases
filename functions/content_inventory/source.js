'use strict';
const model=require('./model');
const SOURCES=Object.freeze({
 drugs:{repository:'https://github.com/rodrigssousa-sudo/medcases-calculadora',slug:'rodrigssousa-sudo/medcases-calculadora',ref:'main'},
 pathologies:{repository:'https://github.com/rodrigssousa-sudo/MedCases',slug:'rodrigssousa-sudo/MedCases',ref:'main',path:'assets/clinical/clinical_registry_phase24_authoritative270.json'}
});
async function json(url, fetcher=fetch) {
 for(let attempt=0;attempt<3;attempt++){
  try {
   const r=await fetcher(url,{headers:{Accept:'application/vnd.github+json','User-Agent':'MedCases-Metadata-Inventory'},signal:AbortSignal.timeout(30000),redirect:'error'});
   if(!r.ok)throw Error(`SOURCE_HTTP_${r.status}`);
   if(Number(r.headers.get('content-length'))>32*1024*1024)throw Error('SOURCE_SIZE_LIMIT');
   const chunks=[];let size=0;for await(const chunk of r.body){size+=chunk.length;if(size>32*1024*1024)throw Error('SOURCE_SIZE_LIMIT');chunks.push(Buffer.from(chunk));}
   try{return JSON.parse(Buffer.concat(chunks).toString('utf8'));}catch(_){throw Error('SOURCE_JSON_INVALID');}
  }catch(e){
   const transient=e.name==='TimeoutError'||e.name==='AbortError'||e instanceof TypeError||/^SOURCE_HTTP_(429|5[0-9]{2})$/.test(e.message);
   if(!transient||attempt===2)throw Error(transient?'SOURCE_NETWORK_RETRIES_EXHAUSTED':e.message);
   await new Promise(resolve=>setTimeout(resolve,500*(attempt+1)));
  }
 }
}
async function loadSource(kind,{fetcher=fetch,previous=[]}={}) {
 const config=SOURCES[kind];if(!config)throw Error('INVALID_INVENTORY_KIND');
 const commit=await json(`https://api.github.com/repos/${config.slug}/commits/${config.ref}`,fetcher);
 const source={repository:config.repository,revision:commit.sha};
 if(!/^[a-f0-9]{40}$/.test(source.revision))throw Error('INVALID_SOURCE_REVISION');
 const raw=path=>json(`https://raw.githubusercontent.com/${config.slug}/${source.revision}/${path}`,fetcher);
 if(kind==='pathologies'){
  const registry=await raw(config.path);
  if(!Array.isArray(registry.identities)||!Array.isArray(registry.content)||!Array.isArray(registry.managementRules)||registry.identities.length===0)throw Error('SOURCE_SCHEMA_CHANGED');
  const rows=registry.identities.map(x=>model.pathology(x,registry,source,config.path,model.hash(registry)));
  return {source,rows,sourceMode:registry.mode,sourceVersion:registry.build,itemsRead:rows.length};
 }
 let treeSha=commit.commit.tree.sha;
 for(const directory of ['data','drugs']){
  const tree=await json(`https://api.github.com/repos/${config.slug}/git/trees/${treeSha}`,fetcher);
  if(tree.truncated)throw Error('SOURCE_TREE_TRUNCATED');
  const entry=tree.tree.find(x=>x.path===directory&&x.type==='tree');
  if(!entry)throw Error('SOURCE_DIRECTORY_MISSING');treeSha=entry.sha;
 }
 const tree=await json(`https://api.github.com/repos/${config.slug}/git/trees/${treeSha}`,fetcher);
 if(tree.truncated)throw Error('SOURCE_TREE_TRUNCATED');
 const entries=tree.tree.filter(x=>/^[^/]+\.json$/.test(x.path)&&x.type==='blob').map(x=>({...x,path:`data/drugs/${x.path}`}));
 if(!entries.length||entries.length>10000)throw Error('SOURCE_COUNT_INVALID');
 const catalog=await raw('data/drugs_index.json');if(!Array.isArray(catalog))throw Error('SOURCE_CATALOG_INVALID');
 const ids=new Set(catalog.map(x=>x.id)),cache=new Map(previous.map(x=>[x.sourcePath,x]));
 const rows=new Array(entries.length);let next=0;
 await Promise.all(Array.from({length:8},async()=>{while(next<entries.length){const i=next++, e=entries[i],old=cache.get(e.path);
  rows[i]=old?.sourceBlob===e.sha?{...old,sourceRevision:source.revision,sourceVersion:source.revision,sourceUrl:`${source.repository}/blob/${source.revision}/${e.path}`,syncStatus:'SYNCED',missingInSource:false,inCatalog:ids.has(old.canonicalId)}:model.drug(await raw(e.path),source,e.path,e.sha,ids);
 }}));
 const missing=catalog.filter(x=>!rows.some(r=>r.canonicalId===x.id));
 // No partial inventory can become visible when catalog references are unresolved.
 if(missing.length)throw Error('CATALOG_DETAIL_MISSING');
 return {source,rows,itemsRead:entries.length,sourceMode:'REPOSITORY_DETAIL_FILES',sourceVersion:source.revision};
}
module.exports={SOURCES,loadSource,json};

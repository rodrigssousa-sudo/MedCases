const path=require('path');
function mime(p){const x=path.extname(p);return ({'.js':'text/javascript','.wasm':'application/wasm','.json':'application/json','.html':'text/html','.png':'image/png','.svg':'image/svg+xml','.jpg':'image/jpeg','.woff2':'font/woff2','.ttf':'font/ttf'})[x]||'application/octet-stream'}
function clinicalRequest(raw){const u=new URL(raw);return /\/(stream|plantao|mcc1|ledger|quota)(\/|$)/i.test(u.pathname)||/plantaoproxystream|medcasesclinical/i.test(u.hostname)}
function assetContract(observed,expected){for(const [file,hash] of Object.entries(expected)){if(observed[file]!==hash)throw Error('ASSET_HASH_MISMATCH:'+file)}}
function cacheContract(entries,hash){if(entries.length===0)throw Error('MAIN_NOT_PRESENT_IN_CACHE');if(entries.some(x=>x.hash!==hash))throw Error('STALE_MAIN_CACHE')}
function safePath(root,relative){const p=path.resolve(root,relative.replace(/^\//,''));if(p!==root&&!p.startsWith(root+path.sep))throw Error('INVALID_STATIC_PATH');return p}
module.exports={mime,clinicalRequest,assetContract,cacheContract,safePath};
// The legacy SW is network-first for main/bootstrap; warm-cache proof must
// inspect bytes actually cached by its static-asset policy, not invent a main entry.
function warmCacheContract(entries,expected){
 const own=entries.filter(e=>e.path&&expected[e.path]);
 if(!own.some(e=>e.path.startsWith('assets/')))throw Error('APP_STATIC_CACHE_NOT_PROVEN');
 for(const e of own)if(e.hash!==expected[e.path])throw Error('INCOMPATIBLE_CACHED_ASSET:'+e.path);
}
module.exports.warmCacheContract=warmCacheContract;

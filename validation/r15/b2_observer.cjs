const fs=require('fs');
function safeURL(raw){try{const u=new URL(raw);return u.origin+u.pathname.replace(/\/users\/[^/]+/g,'/users/[redacted]')}catch{return '[invalid-url]'}}
function sanitize(raw){return String(raw).replace(/https?:\/\/[^\s"'<>]+/g,safeURL).replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi,'[email]').replace(/\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g,'[token]').replace(/((?:token|authorization|password|uid|apiKey)\s*[:=]\s*)[^\s,;]+/gi,'$1[redacted]').slice(0,1500)}
function createObserver(out,phase){
 const events=[];const append=(type,data)=>{const event={utc:new Date().toISOString(),phase:phase(),type,...data};events.push(event);fs.appendFileSync(out+'/browser-events.jsonl',JSON.stringify(event)+'\n')};
 function attach(page){
  page.on('console',m=>append('console',{level:m.type(),message:sanitize(m.text())}));
  page.on('pageerror',e=>append('pageerror',{name:e.name,message:sanitize(e.message)}));
  page.on('requestfailed',r=>append('requestfailed',{url:safeURL(r.url()),resourceType:r.resourceType(),reason:sanitize(r.failure()?.errorText)}));
  page.on('response',r=>{if(r.status()>=400||['script','font','wasm'].includes(r.request().resourceType())||/\.(wasm|woff2?|ttf)(\?|$)/.test(r.url()))append('response',{url:safeURL(r.url()),status:r.status(),resourceType:r.request().resourceType()})});
 }
 async function snapshot(page,label){
  if(!page||page.isClosed())return;
  try{
   const state=await page.evaluate(async()=>{
    const roots=[document];for(let i=0;i<roots.length;i++)for(const e of roots[i].querySelectorAll('*'))if(e.shadowRoot)roots.push(e.shadowRoot);
    const nodes=roots.flatMap(r=>[...r.querySelectorAll('flutter-view,flt-glass-pane,flt-scene-host,canvas,flt-semantics-host')]).map(e=>{const b=e.getBoundingClientRect(),c=getComputedStyle(e);return {tag:e.tagName,width:b.width,height:b.height,visible:c.visibility!=='hidden'&&c.display!=='none',pixelWidth:e.width||null,pixelHeight:e.height||null}});
    const splash=document.querySelector('#loading');
    const dom=roots.map((r,i)=>({root:i,nodes:[...r.querySelectorAll('*')].slice(0,1000).map(e=>({tag:e.tagName,id:e.id,children:e.childElementCount}))}));
    const sw=await navigator.serviceWorker.getRegistrations();
    return {firstFrame:window.__r15FirstFrame===true,readyState:document.readyState,splashPresent:!!splash,nodes,dom,serviceWorkers:sw.map(r=>({scope:r.scope,active:r.active?.scriptURL,activeState:r.active?.state,waiting:r.waiting?.scriptURL,installing:r.installing?.scriptURL})),controller:navigator.serviceWorker.controller?.scriptURL,cacheNames:await caches.keys(),cacheEntries:await Promise.all((await caches.keys()).map(async name=>({name,urls:(await(await caches.open(name)).keys()).map(r=>r.url)}))),navigation:performance.getEntriesByType('navigation').map(x=>({type:x.type,domContentLoadedEventEnd:x.domContentLoadedEventEnd,loadEventEnd:x.loadEventEnd,duration:x.duration})),resources:performance.getEntriesByType('resource').map(x=>({url:x.name,initiator:x.initiatorType,duration:x.duration,transferSize:x.transferSize}))};
   });
   for(const x of state.resources)x.url=safeURL(x.url);for(const x of state.cacheEntries)x.urls=x.urls.map(safeURL);
   fs.writeFileSync(out+'/'+label+'-browser-state.json',JSON.stringify(state,null,2));
   await page.screenshot({path:out+'/'+label+'.png'});return state;
  }catch(e){append('snapshot-error',{label,message:sanitize(e.message)})}
 }
 return {attach,snapshot,events,append,blocked:(url)=>append('blocked',{url:safeURL(url)}),fatal:()=>events.some(e=>e.phase===phase()&&e.type==='pageerror')};
}
module.exports={safeURL,sanitize,createObserver};

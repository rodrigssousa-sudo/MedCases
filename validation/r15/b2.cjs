const fs=require('fs'),http=require('http'),crypto=require('crypto'),cp=require('child_process');
const {chromium}=require('playwright');
const {installLocaleProbe,localeReadback}=require('./b2_locale.cjs');
const {createObserver,sanitize}=require('./b2_observer.cjs');
const {startStaticOrigin}=require('./b2_static_origin.cjs');
const {mime,clinicalRequest,assetContract,cacheContract,warmCacheContract,safePath}=require('./b2_contract.cjs');
const root='/data',out='/receipts';let phase='old',browser,emulator,server,staticOrigin,page,stage='INIT';
const binding=JSON.parse(fs.readFileSync(root+'/binding.json'));
const result={B2_WARM_CLIENT:'NOT_EXECUTED',B2_CACHE_UPDATE:'NOT_EXECUTED',B2_SESSION_PRESERVED:'NOT_EXECUTED',B2_SERVICE_WORKER:'NOT_EXECUTED',B2_NO_CLINICAL_QUERIES:'NOT_EXECUTED',sessionType:'FIREBASE_AUTH_EMULATOR_NAMED_APP_STORAGE_CONTINUITY',commercialLoginTested:false,productionMutations:0,externalNetwork:'DOCKER_NETWORK_NONE'};
const observer=createObserver(out,()=>phase);
let clinical=0,navigations=0;const blocked=new Set(),scriptHashes={old:{},new:{}};
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const assert=(v,m)=>{if(!v)throw Error(m)};
const delay=ms=>new Promise(r=>setTimeout(r,ms));
async function authSession(page,create){return page.evaluate(async(create)=>{
 const a=await import('https://www.gstatic.com/firebasejs/11.9.1/firebase-app.js');
 const s=await import('https://www.gstatic.com/firebasejs/11.9.1/firebase-auth.js');
 const app=a.getApps().find(x=>x.name==='r15-validation')||a.initializeApp({apiKey:'fake-emulator-key',projectId:'demo-r15-validation',authDomain:'localhost'},'r15-validation');
 const auth=s.getAuth(app);
 if(!auth.emulatorConfig)s.connectAuthEmulator(auth,'http://127.0.0.1:9099',{disableWarnings:true});
 await s.setPersistence(auth,s.indexedDBLocalPersistence);
 await auth.authStateReady();
 if(create)await s.signInAnonymously(auth);
 return auth.currentUser?auth.currentUser.uid:null;
 },create)}
async function firstFrame(p){try{await p.waitForFunction(()=>window.__r15FirstFrame===true,{},{timeout:90000});assert(!observer.fatal(),'FATAL_JAVASCRIPT_ERROR');await p.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));const state=await observer.snapshot(p,phase+'-first-frame');assert(state&&!state.splashPresent&&state.nodes.some(n=>n.tag==='CANVAS'&&n.visible&&n.width>0&&n.height>0&&n.pixelWidth>0),'FLUTTER_RENDER_NOT_PROVEN')}catch(e){await observer.snapshot(p,phase+'-frame-failure');throw e}}
async function hashes(p){return p.evaluate(async(files)=>{const result={};for(const file of files){const r=await fetch('/'+file,{cache:'no-store'});if(r.status!==200)throw Error('ASSET_HTTP');const b=await r.arrayBuffer();result[file]=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',b))).map(v=>v.toString(16).padStart(2,'0')).join('')}return result},Object.keys(binding.old))}
async function cacheEntries(p){return p.evaluate(async()=>{const out=[];for(const name of await caches.keys()){const c=await caches.open(name);for(const req of await c.keys()){if(new URL(req.url).origin===location.origin){const b=await(await c.match(req)).arrayBuffer();out.push({name,path:new URL(req.url).pathname.slice(1),hash:Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',b))).map(v=>v.toString(16).padStart(2,'0')).join('')})}}}return out})}
function observe(p){observer.attach(p);p.on('request',r=>{if(r.isNavigationRequest()&&r.frame()===p.mainFrame())navigations++});p.on('response',async r=>{const key=new URL(r.url()).pathname.slice(1),atPhase=phase;if(['main.dart.js','flutter_bootstrap.js'].includes(key)&&r.request().resourceType()==='script'){try{scriptHashes[atPhase][key]=sha(await r.body())}catch(e){}}})}
(async()=>{try{
 stage='AUTH_EMULATOR_STARTUP';
 fs.writeFileSync('/tmp/firebase.json',JSON.stringify({emulators:{auth:{host:'127.0.0.1',port:9099},ui:{enabled:false},singleProjectMode:true}}));
 emulator=cp.spawn('/opt/test/node_modules/.bin/firebase',['emulators:start','--only','auth','--project','demo-r15-validation','--config','/tmp/firebase.json'],{cwd:'/tmp',env:{PATH:process.env.PATH,HOME:'/tmp',CI:'true'},stdio:'ignore'});
 for(let n=0;n<60;n++){if(emulator.exitCode!==null)throw Error('AUTH_EMULATOR_EXIT:'+emulator.exitCode);try{const r=await fetch('http://127.0.0.1:9099/');if(r.status>=500)throw Error('AUTH_EMULATOR_NOT_READY');break}catch(e){if(n===59)throw Error('AUTH_EMULATOR_STARTUP');await delay(500)}}
 const actualMeta=JSON.parse(fs.readFileSync(out+'/startup-deploy-meta.json'));assert(actualMeta.deployCommit===binding.base,'B1_META_MISMATCH');
 server=http.createServer((req,res)=>{
  let p;try{p=decodeURIComponent(new URL(req.url,'http://localhost').pathname)}catch(e){res.writeHead(400).end();return}
  if(p==='/deploy_meta.json'&&phase==='new'){res.setHeader('Content-Type','application/json');res.setHeader('Cache-Control','no-store');res.end(JSON.stringify(actualMeta));return}
  let file;try{file=p.startsWith('/_vendor/')?safePath(root+'/vendor',p.slice(9)):safePath(root+'/'+phase,p==='/'?'index.html':p)}catch(e){res.writeHead(403).end();return}
  if(!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404).end();return}
  res.setHeader('Content-Type',mime(file));res.setHeader('Cache-Control',/\.js$|deploy_meta/.test(file)?'no-store':'public,max-age=3600');res.end(fs.readFileSync(file));
 });await new Promise(r=>server.listen(8080,'127.0.0.1',r));
 staticOrigin=await startStaticOrigin(root,()=>phase,observer);
 browser=await chromium.launch({headless:true,args:['--no-sandbox','--disable-dev-shm-usage',...staticOrigin.args]});
 result.chromiumVersion=browser.version();
 result.runnerLocale={LANG:process.env.LANG||null,LC_ALL:process.env.LC_ALL||null,LC_CTYPE:process.env.LC_CTYPE||null};
 const context=await browser.newContext({viewport:{width:1440,height:1000},serviceWorkers:'allow'});
 await context.exposeBinding('__r15RecordLocaleFailure',(_,event)=>observer.append('intl-failure',event));
 await context.addInitScript(installLocaleProbe);
 await context.addInitScript(()=>{window.__r15FirstFrame=false;window.addEventListener('flutter-first-frame',()=>{window.__r15FirstFrame=true})});
 await context.route('**/*',async route=>{
  const u=new URL(route.request().url());if(u.hostname==='127.0.0.1'&&['8080','9099'].includes(u.port))return route.continue();
  if(u.hostname==='www.gstatic.com')return route.continue(); // loopback TLS serves both page and SW requests
  blocked.add(u.hostname);observer.blocked(u.href);return route.abort('blockedbyclient');
 });
 context.on('request',r=>{if(clinicalRequest(r.url()))clinical++});
 page=await context.newPage();observe(page);
 result.localePreflight=await page.evaluate(localeReadback);
 fs.writeFileSync(out+'/locale-preflight.json',JSON.stringify(result.localePreflight,null,2));
 stage='OLD_CLIENT_FIRST_FRAME';
 await page.goto('http://127.0.0.1:8080/',{waitUntil:'domcontentloaded'});await observer.snapshot(page,phase+'-dom-ready');await firstFrame(page);
 stage='OLD_SW_CACHE';await page.waitForFunction(()=>navigator.serviceWorker.controller!==null,{},{timeout:30000});
 const oldHashes=await hashes(page);assetContract(oldHashes,binding.old);
 stage='OLD_CONTROLLED_REOPEN';await page.reload({waitUntil:'domcontentloaded'});await firstFrame(page);
 for(let n=0;n<50&&(await cacheEntries(page)).length===0;n++)await delay(100);
 warmCacheContract(await cacheEntries(page),JSON.parse(fs.readFileSync(root+'/old-readback.json')));
 assert(scriptHashes.old['main.dart.js']===binding.old['main.dart.js'],'OLD_BUNDLE_NOT_EXECUTED');
 stage='EMULATED_SESSION';const uid=await authSession(page,true);assert(uid,'EMULATOR_SESSION_MISSING');
 await page.screenshot({path:out+'/old-web.png'});
 result.old={hashes:oldHashes,cache:await cacheEntries(page),sessionEstablished:true,controller:await page.evaluate(()=>navigator.serviceWorker.controller.scriptURL)};result.B2_WARM_CLIENT='PASS_REAL';
 assert(!observer.fatal(),'OLD_CLIENT_FATAL_ERROR');phase='new';const navBefore=navigations;stage='UPDATE_DETECTION';
 await page.evaluate(async()=>{window.__r15UpdateDetected=false;const r=await navigator.serviceWorker.getRegistration();r.addEventListener('updatefound',()=>{window.__r15UpdateDetected=true});await r.update()});
 await page.waitForFunction(()=>window.__r15UpdateDetected===true,{},{timeout:30000});
 stage='EXPLICIT_UPDATE';await page.waitForFunction(()=>typeof window.medcasesApplyUpdate==='function');
 const nextNavigation=page.waitForEvent('framenavigated',{predicate:f=>f===page.mainFrame(),timeout:30000});
 await page.evaluate(()=>window.medcasesApplyUpdate());await nextNavigation;await observer.snapshot(page,phase+'-dom-ready');await firstFrame(page);
 for(let n=0;n<90 && scriptHashes.new['main.dart.js']!==binding.bundle.files['main.dart.js'];n++)await delay(1000);
 assetContract(scriptHashes.new,{ 'main.dart.js':binding.bundle.files['main.dart.js'],'flutter_bootstrap.js':binding.bundle.files['flutter_bootstrap.js'] });
 const newHashes=await hashes(page);assetContract(newHashes,Object.fromEntries(Object.keys(binding.old).map(k=>[k,binding.bundle.files[k]])));
 await page.waitForFunction(()=>navigator.serviceWorker.controller!==null,{},{timeout:30000});
 const meta=await page.evaluate(()=>fetch('/deploy_meta.json').then(r=>r.json()));assert(meta.deployCommit===binding.base,'COMMIT_MISMATCH');
 assert(uid===await authSession(page,false),'EMULATOR_SESSION_LOST');
 const entries=await cacheEntries(page);warmCacheContract(entries,binding.bundle.files);
 await delay(10000);assert(navigations-navBefore<=2,'RELOAD_LOOP');assert(clinical===0,'AUTOMATIC_CLINICAL_REQUEST');
 await page.screenshot({path:out+'/new-web.png'});
 result.update={commit:meta.deployCommit,hashes:newHashes,cacheEntries:entries,navigations:navigations-navBefore,controller:await page.evaluate(()=>navigator.serviceWorker.controller.scriptURL)};
 stage='REOPEN_CLIENT';await page.close();page=await context.newPage();observe(page);const reopenStart=navigations;
 await page.goto('http://127.0.0.1:8080/',{waitUntil:'domcontentloaded'});await observer.snapshot(page,phase+'-dom-ready');await firstFrame(page);
 assetContract(await hashes(page),Object.fromEntries(Object.keys(binding.old).map(k=>[k,binding.bundle.files[k]])));
 assert(uid===await authSession(page,false),'REOPEN_SESSION_LOST');await delay(5000);assert(navigations-reopenStart===1,'REOPEN_RELOAD_LOOP');assert(clinical===0,'AUTOMATIC_CLINICAL_REQUEST');
 await page.screenshot({path:out+'/reopened-web.png'});
 Object.assign(result,{B2_CACHE_UPDATE:'PASS_REAL',B2_SESSION_PRESERVED:'PASS_EMULATED',B2_SERVICE_WORKER:'PASS_REAL',B2_NO_CLINICAL_QUERIES:'PASS_REAL',reopened:'PASS_REAL',quotaDebits:0,quotaEvidence:'network=none, no commercial credentials, no clinical request attempted; not commercial ledger validation'});
 assert(!observer.fatal(),'NEW_CLIENT_FATAL_ERROR');stage='COMPLETE';
}catch(e){result.errorClass=e.name;result.error=sanitize(e.message).split('\n')[0].slice(0,180);result.failedStage=stage;process.exitCode=1;await observer.snapshot(page,'failed-stage')
}finally{if(page&&!page.isClosed()){try{fs.writeFileSync(out+'/locale-final.json',JSON.stringify(await page.evaluate(localeReadback),null,2))}catch{}}result.stage=stage;result.blockedHosts=[...blocked];result.clinicalRequests=clinical;result.scriptHashes=scriptHashes;fs.writeFileSync(out+'/b2.json',JSON.stringify(result,null,2));if(browser)await browser.close();if(server)server.close();if(staticOrigin)await staticOrigin.close();if(emulator)emulator.kill('SIGTERM')}})();

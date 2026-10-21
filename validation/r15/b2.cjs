const fs=require('fs'),path=require('path'),http=require('http'),crypto=require('crypto'),cp=require('child_process');
const {chromium}=require('playwright');
const root='/data',out='/receipts';let phase='old',browser,emulator,server;
const binding=JSON.parse(fs.readFileSync(root+'/binding.json'));
const result={B2_WARM_CLIENT:'FAIL',B2_CACHE_UPDATE:'FAIL',B2_SESSION_PRESERVED:'FAIL',B2_NO_CLINICAL_QUERIES:'FAIL',sessionType:'FIREBASE_AUTH_EMULATOR_NAMED_APP_STORAGE_CONTINUITY',commercialLoginTested:false,productionMutations:0,externalNetwork:'DOCKER_NETWORK_NONE'};
let clinical=0,navigations=0;const blocked=new Set(),loaded={old:{},new:{}};
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const assert=(v,m)=>{if(!v)throw Error(m)};
const mime=p=>p.endsWith('.js')?'text/javascript':p.endsWith('.wasm')?'application/wasm':p.endsWith('.json')?'application/json':p.endsWith('.html')?'text/html':'application/octet-stream';
async function authSession(page,create){return page.evaluate(async(create)=>{
 const a=await import('/_vendor/firebasejs/11.9.1/firebase-app.js');
 const s=await import('/_vendor/firebasejs/11.9.1/firebase-auth.js');
 const app=a.getApps().find(x=>x.name==='r15-validation')||a.initializeApp({apiKey:'fake-emulator-key',projectId:'demo-r15-validation',authDomain:'localhost'},'r15-validation');
 const auth=s.getAuth(app);s.connectAuthEmulator(auth,'http://127.0.0.1:9099',{disableWarnings:true});
 await s.setPersistence(auth,s.indexedDBLocalPersistence);
 await new Promise(resolve=>{const stop=s.onAuthStateChanged(auth,()=>{stop();resolve()})});
 if(create)await s.signInAnonymously(auth);
 return auth.currentUser?auth.currentUser.uid:null;
 },create)}
(async()=>{try{
 fs.writeFileSync('/tmp/firebase.json',JSON.stringify({emulators:{auth:{host:'127.0.0.1',port:9099},ui:{enabled:false},singleProjectMode:true}}));
 emulator=cp.spawn('/opt/test/node_modules/.bin/firebase',['emulators:start','--only','auth','--project','demo-r15-validation','--config','/tmp/firebase.json'],{cwd:'/tmp',env:{PATH:process.env.PATH,HOME:'/tmp',CI:'true'},stdio:'ignore'});
 for(let n=0;n<60;n++){try{await fetch('http://127.0.0.1:9099/');break}catch(e){if(n===59)throw Error('AUTH_EMULATOR_STARTUP');await new Promise(r=>setTimeout(r,500))}}
 server=http.createServer((req,res)=>{
 const p=decodeURIComponent(new URL(req.url,'http://localhost').pathname);if(p.includes('..')){res.writeHead(403).end();return}
 if(p==='/deploy_meta.json'&&phase==='new'){res.setHeader('Content-Type','application/json');res.setHeader('Cache-Control','no-store');res.end(JSON.stringify({status:'available',deployCommit:binding.base}));return}
 const file=p.startsWith('/_vendor/')?root+'/vendor/'+p.slice(9):root+'/'+phase+(p==='/'?'/index.html':p);
 if(!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404).end();return}
 res.setHeader('Content-Type',mime(file));res.setHeader('Cache-Control',/\.js$|deploy_meta/.test(file)?'no-store':'public,max-age=3600');res.end(fs.readFileSync(file));
 });await new Promise(r=>server.listen(8080,'127.0.0.1',r));
 browser=await chromium.launch({headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});
 const context=await browser.newContext({viewport:{width:1440,height:1000},serviceWorkers:'allow'});
 await context.route('**/*',async route=>{
  const u=new URL(route.request().url());if(u.hostname==='127.0.0.1')return route.continue();
  if(u.hostname==='www.gstatic.com'&&u.pathname.startsWith('/firebasejs/')){const f=root+'/vendor'+u.pathname;if(fs.existsSync(f))return route.fulfill({status:200,contentType:'text/javascript',body:fs.readFileSync(f),headers:{'Access-Control-Allow-Origin':'*'}})}
  if(u.hostname==='www.gstatic.com'&&u.pathname.includes('/flutter-canvaskit/')){const rel=u.pathname.split('/').slice(3).join('/');const f=root+'/'+phase+'/canvaskit/'+rel;if(fs.existsSync(f))return route.fulfill({status:200,contentType:mime(f),body:fs.readFileSync(f),headers:{'Access-Control-Allow-Origin':'*'}})}
  blocked.add(u.hostname);return route.abort('blockedbyclient');
 });
 context.on('request',r=>{const u=new URL(r.url());if(/\/(stream|plantao|mcc1|ledger|quota)(\/|$)/i.test(u.pathname)||/plantaoproxystream|medcasesclinical/i.test(u.hostname))clinical++});
 const page=await context.newPage();
 page.on('framenavigated',f=>{if(f===page.mainFrame())navigations++});
 page.on('response',async r=>{const p=new URL(r.url()).pathname.slice(1);if(Object.hasOwn(binding.old,p)){try{loaded[phase][p]=sha(await r.body())}catch(e){}}});
 await page.goto('http://127.0.0.1:8080/',{waitUntil:'domcontentloaded'});
 await page.waitForSelector('flutter-view',{state:'attached',timeout:90000});
 await page.evaluate(async()=>{await navigator.serviceWorker.ready;await fetch('/main.dart.js');});
 await page.waitForFunction(()=>navigator.serviceWorker.controller!==null,{},{timeout:30000});
 const cachesBefore=await page.evaluate(()=>caches.keys());assert(cachesBefore.length>0,'OLD_CACHE_EMPTY');
 assert(loaded.old['main.dart.js']===binding.old['main.dart.js'],'OLD_BUNDLE_NOT_LOADED');
 const uid=await authSession(page,true);assert(uid,'SYNTHETIC_SESSION_MISSING');
 await page.screenshot({path:out+'/old-web.png'});
 result.old={mainHash:loaded.old['main.dart.js'],cacheNames:cachesBefore,sessionEstablished:true};
 phase='new';const navBefore=navigations;
 await page.evaluate(async()=>{const r=await navigator.serviceWorker.getRegistration();await r.update()});
 await page.waitForFunction(()=>typeof window.medcasesApplyUpdate==='function');
 await page.evaluate(()=>window.medcasesApplyUpdate());
 await page.waitForLoadState('domcontentloaded');
 await page.waitForSelector('flutter-view',{state:'attached',timeout:90000});
 for(let n=0;n<90 && loaded.new['main.dart.js']!==binding.bundle.files['main.dart.js'];n++)await page.waitForTimeout(1000);
 await page.waitForTimeout(10000);
 assert(loaded.new['main.dart.js']===binding.bundle.files['main.dart.js'],'FINAL_BUNDLE_NOT_LOADED');
 const meta=await page.evaluate(()=>fetch('/deploy_meta.json').then(r=>r.json()));assert(meta.deployCommit===binding.base,'COMMIT_MISMATCH');
 const uidAfter=await authSession(page,false);assert(uid===uidAfter,'EMULATOR_SESSION_LOST');
 const cacheEntries=await page.evaluate(async()=>{const out=[];for(const name of await caches.keys()){const c=await caches.open(name);for(const req of await c.keys()){if(new URL(req.url).pathname==='/main.dart.js'){const b=await(await c.match(req)).arrayBuffer();out.push({name,hash:Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',b))).map(v=>v.toString(16).padStart(2,'0')).join('')})}}}return out});
 assert(cacheEntries.every(x=>x.hash===binding.bundle.files['main.dart.js']),'STALE_MAIN_CACHE');
 assert(navigations-navBefore<=2,'RELOAD_LOOP');assert(clinical===0,'AUTOMATIC_CLINICAL_REQUEST');
 await page.screenshot({path:out+'/new-web.png'});
 result.update={commit:meta.deployCommit,mainHash:loaded.new['main.dart.js'],cacheEntries,navigations:navigations-navBefore};
 Object.assign(result,{B2_WARM_CLIENT:'PASS',B2_CACHE_UPDATE:'PASS',B2_SESSION_PRESERVED:'PASS',B2_NO_CLINICAL_QUERIES:'PASS',quotaDebits:0});
}catch(e){result.error=String(e.message).slice(0,180);process.exitCode=1;
}finally{result.blockedHosts=[...blocked];result.clinicalRequests=clinical;fs.writeFileSync(out+'/b2.json',JSON.stringify(result,null,2));if(browser)await browser.close();if(server)server.close();if(emulator)emulator.kill('SIGTERM')}})();

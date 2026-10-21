// Test-only observation. Native Intl results and exceptions are preserved.
function installLocaleProbe(){
 const events=[];Object.defineProperty(window,'__r15LocaleEvents',{value:events});
 const value=x=>typeof x==='string'?x.slice(0,160):Array.isArray(x)?x.map(value):x===undefined?'[undefined]':'[non-string]';
 for(const name of ['Locale','DateTimeFormat','NumberFormat','getCanonicalLocales','Segmenter','v8BreakIterator']){
  const native=Intl[name];if(typeof native!=='function')continue;
  const invoke=(args,run)=>{try{return run()}catch(e){const event={api:name,locale:value(args[0]),name:e.name,message:String(e.message).slice(0,300),stack:String(e.stack).slice(0,6000),language:navigator.language,languages:[...navigator.languages]};events.push(event);if(typeof window.__r15RecordLocaleFailure==='function')Promise.resolve(window.__r15RecordLocaleFailure(event)).catch(()=>{});throw e}};
  Intl[name]=new Proxy(native,{apply:(target,self,args)=>invoke(args,()=>Reflect.apply(target,self,args)),construct:(target,args,newTarget)=>invoke(args,()=>Reflect.construct(target,args,newTarget))});
 }
}
function localeReadback(){
 const cases=[...new Set([...navigator.languages,'pt-BR','es-AR'])];
 return {language:navigator.language,languages:[...navigator.languages],defaultDateLocale:new Intl.DateTimeFormat().resolvedOptions().locale,cases:cases.map(locale=>{try{return {locale,canonical:Intl.getCanonicalLocales(locale),intlLocale:new Intl.Locale(locale).toString(),date:new Intl.DateTimeFormat(locale).resolvedOptions().locale,number:new Intl.NumberFormat(locale).resolvedOptions().locale,segmenter:typeof Intl.Segmenter==='function'?new Intl.Segmenter(locale).resolvedOptions().locale:null,status:'PASS'}}catch(e){return {locale,status:'FAIL',error:e.name,message:e.message}}}),failures:window.__r15LocaleEvents||[]};
}
function requireConfiguredLocale(r){
 if(r.language!=='pt-BR'||!Array.isArray(r.languages)||!r.languages.length||!r.languages.includes('pt-BR')||r.languages.includes('en-US@posix'))throw Error('BROWSER_LOCALE_MISMATCH');
 for(const locale of [...r.languages,'pt-BR','es-AR']){
  const c=r.cases.find(x=>x.locale===locale);
  if(!c||c.status!=='PASS'||!c.canonical?.length||!c.intlLocale||!c.date||!c.number||!c.segmenter)throw Error('BROWSER_INTL_LOCALE_INVALID');
 }
 if(r.failures.length)throw Error('BROWSER_INTL_FAILURE');
}
module.exports={installLocaleProbe,localeReadback,requireConfiguredLocale};

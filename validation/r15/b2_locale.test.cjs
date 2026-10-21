const {test}=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm');
const {installLocaleProbe,localeReadback}=require('./b2_locale.cjs');
function realm(language){const c=vm.createContext({navigator:{language,languages:[language]},window:{}});vm.runInContext('('+installLocaleProbe.toString()+')()',c);return c}
for(const locale of ['pt-BR','es-AR'])test('native Intl accepts '+locale,()=>{const c=realm(locale),r=vm.runInContext('('+localeReadback.toString()+')()',c);assert(r.cases.every(x=>x.status==='PASS'));assert.equal(r.language,locale);assert.equal(r.failures.length,0)});
test('invalid synthetic locale is recorded and rethrown, never repaired',()=>{const c=realm('en-US@posix');assert.throws(()=>vm.runInContext('new Intl.Locale(navigator.language)',c),/Incorrect locale/);assert.equal(c.window.__r15LocaleEvents[0].locale,'en-US@posix');assert.equal(c.window.__r15LocaleEvents[0].api,'Locale');assert.equal(c.window.__r15LocaleEvents[0].name,'RangeError')});
test('formatters and canonicalizer preserve native rejection',()=>{for(const api of ['DateTimeFormat','NumberFormat','getCanonicalLocales','Segmenter']){const c=realm('pt-BR');assert.throws(()=>vm.runInContext('Intl.'+api+'("not_a_locale")',c));assert.equal(c.window.__r15LocaleEvents[0].api,api)}});

test('B2 does not replace navigator or force a locale',()=>{const s=require('node:fs').readFileSync(__dirname+'/b2.cjs','utf8');assert(!s.includes("locale:'pt-BR'"));assert(s.includes("context.addInitScript(installLocaleProbe)"))});

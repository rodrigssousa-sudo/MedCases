'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
test('actual injected bridge expires/revokes visual tier and captured fetch handles',async()=>{
 const dart=fs.readFileSync(path.join(__dirname,'../../lib/screens/calculadora_screen.dart'),'utf8');
 const template=dart.match(/final source = """\n([\s\S]*?)\n""";/)[1];
 let now=2000000000000;let fetches=0;let timer;const events=[];
 const source=template.replaceAll('$featuresJson',JSON.stringify(['drugsWeightDose','drugsAdvancedInfusion'])).replaceAll('$tokenJson',JSON.stringify('test-token')).replaceAll('$tierJson',JSON.stringify('premium')).replaceAll('$capabilitiesJson',JSON.stringify(['drug_catalog_full'])).replaceAll('$expiresAtJson',JSON.stringify(new Date(now+1000).toISOString()));
 const win={location:{protocol:'https:',hostname:'medcasescalcu.com',origin:'https://medcasescalcu.com'},dispatchEvent:e=>events.push(e)};
 const context={window:win,Date:class extends Date{static now(){return now;}},URL,Headers,fetch:async()=>{fetches++;return {};},CustomEvent:class{constructor(name,data){this.name=name;this.detail=data.detail;}},setTimeout:fn=>timer=fn};
 vm.runInNewContext(source,context);const bridge=win.__medcasesMcc1Bridge;assert.equal(bridge.tier,'premium');await bridge.fetch('/api/drugs');assert.equal(fetches,1);
 now+=1000;timer();assert.equal(bridge.tier,'free');assert.equal(bridge.capabilities.length,0);assert.equal(events.at(-1).detail.tier,'free');await assert.rejects(bridge.fetch('/api/drugs'),/SESSION_EXPIRED/);
 now-=1000;bridge.revoke();assert.equal(bridge.tier,'free');await assert.rejects(bridge.fetch('/api/drugs'),/SESSION_EXPIRED/);
});

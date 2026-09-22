'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs'),path=require('node:path');
test('actual action wrappers block direct invocation, preserve warnings and clinical hard gates',()=>{
 const dart=fs.readFileSync(path.join(__dirname,'../../lib/services/entitlement_webview_contract.dart'),'utf8');
 const script=dart.match(/r'''([\s\S]*?)'''/)[1];
 for(const state of ['FREE','TRIAL','PAID','EXPIRED']){
  let calls=0,wall=0;const allowed=['TRIAL','PAID'].includes(state);
  const win={MCUpgrade:{postMessage(){wall++;}},__medcasesMcc1Bridge:{features:allowed?['drugsWeightDose','drugsAdvancedInfusion']:[]},warning:'clinical warning remains'};
  for(const name of ['_fdCalcDoseFromModal','calcDrugDose','calcShowInlineResult','calculateInfusion'])win[name]=()=>{calls++;return {calculationAuthorized:false,pediatricAuthority:false};};
  vm.runInNewContext(script,{window:win,document:{documentElement:{lang:'pt'}}});
  for(const name of ['_fdCalcDoseFromModal','calcDrugDose','calcShowInlineResult','calculateInfusion']){
   const result=win[name]();if(allowed){assert.equal(result.calculationAuthorized,false);assert.equal(result.pediatricAuthority,false);}else assert.equal(result,undefined);
  }
  assert.equal(calls,allowed?4:0);assert.equal(wall,allowed?0:4);assert.equal(win.warning,'clinical warning remains');
 }
});

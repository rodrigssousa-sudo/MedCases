'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {SnapshotDecoder, SnapshotCoordinator, snapshotKey, validateRecord, canonicalFacts, renderRecord, renderSnapshot, renderClinicalRecord, validateSnapshot, hash, VERSION} = require('../plantao_clinical_snapshot');
const title = {type:'title',id:'synthetic_topic',labels:{pt:'Tema sintético',es:'Tema sintético'}};
const section = {type:'section',id:'reference_doses',facts:[{
  id:'reference_regimen',action:'explain',polarity:'conditional',conceptCodes:['synthetic_agent'],conditionCodes:['general_education'],slots:[
    {id:'agent',kind:'clinical_concept',value:'synthetic_agent',labels:{pt:'Agente fictício',es:'Agente ficticio'}},
    {id:'amount',kind:'quantity',value:'42 mg'},
  ],template:'{{agent}}: **{{amount}}**.',
}]};
const context = {uid:'qa_a',requestFrame:{topic:'synthetic_topic',intent:'reference_regimen'},context:{},history:[],knowledgeVersion:'test_1',grounding:[],policyVersion:'safety_test_1'};
function snapshot() {const d=new SnapshotDecoder({language:'pt',onBlock:()=>{}});d.accept(JSON.stringify(title)+'\n'+JSON.stringify(section)+'\n');return d.complete();}
class Store {
 constructor(){this.data=new Map();this.locks=new Map();}
 async get(uid,key){return this.data.get(uid+':'+key);}
 async put(uid,key,value){this.data.set(uid+':'+key,value);}
 async withLease(uid,key,fn){const id=uid+':'+key;const prior=this.locks.get(id)||Promise.resolve();let release;const gate=new Promise(r=>release=r);const chain=prior.then(()=>gate);this.locks.set(id,chain);await prior;try{return await fn();}finally{release();if(this.locks.get(id)===chain)this.locks.delete(id);}}
}
test('paired PT/ES rendering uses same facts, sections, quantities and priorities',()=>{
 const s=snapshot(); const projected=Object.fromEntries(['pt','es'].map(lang=>[lang,renderSnapshot(s,lang).join('')]));
 assert.notEqual(projected.pt,projected.es);assert.ok(projected.pt.includes('42 mg'));assert.ok(projected.es.includes('42 mg'));
 assert.equal(hash(s.clinical),s.factsHash);assert.ok(Object.isFrozen(s.clinical[1].facts[0]));
});
test('semantic block is visible before provider completion and never reformatted',()=>{
 const blocks=[];const d=new SnapshotDecoder({language:'es',onBlock:b=>blocks.push(b)});
 const wire=JSON.stringify(title)+'\n'+JSON.stringify(section)+'\n';
 for(const c of wire)d.accept(c);
 assert.equal(d.finished,false);assert.equal(blocks.length,2);const before=[...blocks];d.complete();assert.deepEqual(blocks,before);
});
test('partial JSON never leaks to renderer',()=>{const blocks=[];const d=new SnapshotDecoder({language:'pt',onBlock:b=>blocks.push(b)});d.accept(JSON.stringify(title).slice(0,25));assert.equal(blocks.length,0);assert.throws(()=>d.complete());});
test('locale cannot change a dose, add a number, omit a fact or duplicate a slot',()=>{
 for(const mutate of [r=>r.facts[0].slots[1].labels={pt:'42 mg',es:'84 mg'},r=>r.facts[0].template+=' 84 mg',r=>r.facts[0].template='{{agent}}',r=>r.facts[0].template='{{agent}} {{amount}} {{amount}}']){
  const r=structuredClone(section);mutate(r);assert.throws(()=>validateRecord(r));
 }
});
test('locale cannot inject markdown sections or references',()=>{for(const suffix of ['\n## Otra sección',' https://invented.example',' PMID: abc']){const r=structuredClone(section);r.facts[0].template+=suffix;assert.throws(()=>validateRecord(r));}});
test('references are selected once from real supplied source IDs',()=>{
 const refs=[{id:'source_1',title:'Provided source',url:'https://example.test/primary'}];
 const r=validateRecord({type:'references',sourceIds:['source_1']},refs);
 assert.ok(renderRecord(r,'pt',refs).includes(refs[0].url));assert.ok(renderRecord(r,'es',refs).includes(refs[0].url));
 assert.throws(()=>validateRecord({type:'references',sourceIds:['invented']},refs));
});
test('duplicate sections and reordering a second title are rejected before emission',()=>{
 const d=new SnapshotDecoder({language:'es',onBlock:()=>{}});d.accept(JSON.stringify(title)+'\n'+JSON.stringify(section)+'\n');assert.throws(()=>d.accept(JSON.stringify(section)+'\n'));
});
test('all context and knowledge dependencies invalidate snapshot identity; locale does not',()=>{
 const key=snapshotKey(context);assert.equal(key,snapshotKey({...context,language:'es'}));
 for(const c of [{uid:'qa_b'},{requestFrame:{topic:'other'}},{context:{weightKg:20}},{history:[{role:'user',content:'different'}]},{knowledgeVersion:'test_2'},{grounding:[{revision:'changed'}]},{policyVersion:'safety_2'}])assert.notEqual(key,snapshotKey({...context,...c}));
 assert.throws(()=>snapshotKey({...context,uid:''}));assert.throws(()=>snapshotKey({...context,grounding:undefined}));
});
for(const topic of ['metformin','acs','hepatic_encephalopathy','hyperkalemia','sepsis']) {
 test(topic+' repeats frozen clinical facts, dose and section order 10 of 10',async()=>{
  const store=new Store();const service=new SnapshotCoordinator(store);let generations=0;const outputs=[];
  for(let i=0;i<10;i++) outputs.push(await service.getOrCreate({...context,requestFrame:{topic},language:i%2?'pt':'es'},async()=>{generations++;return snapshot();}));
  assert.equal(generations,1);assert.equal(new Set(outputs.map(s=>s.factsHash)).size,1);assert.ok(outputs.every(s=>JSON.stringify(s.clinical)===JSON.stringify(outputs[0].clinical)));
 });
}
test('two coordinators acquire shared lease before generation, preventing divergent visible answers',async()=>{
 const store=new Store();const a=new SnapshotCoordinator(store),b=new SnapshotCoordinator(store);let generations=0;
 const create=async()=>{generations++;await new Promise(r=>setTimeout(r,5));return snapshot();};
 const out=await Promise.all([a.getOrCreate(context,create),b.getOrCreate(context,create)]);
 assert.equal(generations,1);assert.equal(out[0].factsHash,out[1].factsHash);
});
test('failed generation is not cached and in-flight lease is released',async()=>{
 const store=new Store();const service=new SnapshotCoordinator(store);await assert.rejects(service.getOrCreate(context,async()=>{throw Error('provider_failed');}));
 assert.equal(store.data.size,0);assert.equal((await service.getOrCreate(context,async()=>snapshot())).version,VERSION);
});
test('different users never reuse a clinical answer',async()=>{const s=new SnapshotCoordinator(new Store());let n=0;for(const uid of ['qa_a','qa_b'])await s.getOrCreate({...context,uid},async()=>{n++;return snapshot();});assert.equal(n,2);});
test('shared quantity never leaks localized clinical prose into the other language',()=>{const r=structuredClone(section);for(const s of r.facts[0].slots.filter(x=>x.kind==='quantity')){s.value='42 mg cada día';}assert.throws(()=>validateRecord(r),/language_neutral/);});
test('pretty printed objects and escaped braces stream without raw JSON or lost records',()=>{
 const blocks=[];const d=new SnapshotDecoder({language:'pt',onBlock:b=>blocks.push(b)});
 const wire='```json\n'+JSON.stringify(title,null,2)+'\n'+JSON.stringify(section,null,2)+'\n```';
 for(const char of wire)d.accept(char);assert.equal(d.complete().clinical.length,2);assert.equal(blocks.length,2);assert.ok(!blocks.join('').includes('"type"'));
});

test('canonical representation has no language field or localized presentation text',()=>{
 const s=snapshot();
 assert.equal(hash(s.clinical),s.factsHash);
 assert.ok(!JSON.stringify(s.clinical).includes('Agente fictício'));
 assert.ok(!JSON.stringify(s.clinical).includes('Referencia sintética'));
 assert.ok(!JSON.stringify(s.clinical).includes('localization'));
 assert.ok(!JSON.stringify(s.clinical).includes('labels'));
 assert.ok(!JSON.stringify(s.presentation).includes('42 mg'));
 assert.deepEqual(s.clinical[1].facts[0].slots[1],{id:'amount',kind:'quantity',value:'42 mg'});
 const p=structuredClone(s.presentation[1]);p.facts[0].id='different_fact';
 assert.throws(()=>renderClinicalRecord(s.clinical[1],p,'es'),/fact_order/);
});

test('numeric disease type is a canonical concept, never a translated dose or threshold',()=>{
 const r=structuredClone(section);
 r.facts[0].slots.push({id:'condition',kind:'condition',value:'diabetes_type_2',labels:{pt:'diabetes tipo 2',es:'diabetes tipo 2'}});
 r.facts[0].template+=' {{condition}}';
 assert.doesNotThrow(()=>validateRecord(r));
 r.facts[0].slots[2].labels.es='diabetes tipo 1';assert.throws(()=>validateRecord(r));
 r.facts[0].slots[2].labels={pt:'TFG <30 mL/min',es:'TFG <30 mL/min'};assert.throws(()=>validateRecord(r));
});

test('snapshot reload validates the clinical hash and both localized projections',()=>{
 const changed=structuredClone(snapshot());changed.clinical[1].facts[0].slots[1].value='84 mg';
 assert.throws(()=>validateSnapshot(changed),/stored_facts_hash_mismatch/);
 const omitted=structuredClone(snapshot());delete omitted.presentation[1].facts[0].labels.agent.pt;
 assert.throws(()=>validateSnapshot(omitted),/missing_field/);
});
test('one canonical expression renders all concept IDs in both languages without independent templates',()=>{
 const r=validateRecord(section); const s=snapshot();
 assert.equal(s.clinical[1].facts[0].template,'{{agent}}: **{{amount}}**.');
 for(const lang of ['pt','es']) {
  const rendered=renderRecord(r,lang);
  assert.ok(rendered.includes(r.facts[0].slots[0].labels[lang]));
  assert.equal((rendered.match(/42 mg/g)||[]).length,1);
 }
 const bad=structuredClone(section);bad.facts[0].template='{{amount}}';
 assert.throws(()=>validateRecord(bad),/canonical_binding_mismatch/);
 const missing=structuredClone(section);delete missing.facts[0].slots[0].labels.pt;
 assert.throws(()=>validateRecord(missing),/missing_field/);
});

test('paired relation labels cannot independently introduce a dose',()=>{
 const r=structuredClone(section);
 r.facts[0].slots.push({id:'instruction',kind:'relation',value:'oral_use',labels:{pt:'por via oral',es:'por vía oral'}});
 r.facts[0].template+=' {{instruction}}';
 assert.doesNotThrow(()=>validateRecord(r));
 r.facts[0].slots[2].labels.es='por vía oral 84 mg';
 assert.throws(()=>validateRecord(r));
});

test('JSON schema envelope renders closed records before the complete array, at every byte boundary',()=>{
 const wire=JSON.stringify({records:[title,section]});
 const blocks=[];const d=new SnapshotDecoder({language:'pt',framing:'json',onBlock:b=>blocks.push(b)});
 for(const char of wire.slice(0,-2))d.accept(char);
 assert.equal(blocks.length,2);assert.equal(d.finished,false);
 assert.throws(()=>d.complete(),/incomplete_envelope/);
 d.accept(wire.slice(-2));const before=[...blocks];d.complete();assert.deepEqual(blocks,before);
});
test('envelope rejects missing delimiters, trailing data and incomplete records',()=>{
 for(const wire of ['{"records":['+JSON.stringify(title)+JSON.stringify(section)+']}',JSON.stringify({records:[title,section]})+'{}']) {
  const d=new SnapshotDecoder({language:'es',framing:'json',onBlock:()=>{}});assert.throws(()=>d.accept(wire));
 }
});
test('paired label quantities lower to shared IDs without changing either localized sentence',()=>{
 const r=structuredClone(section);
 const slot={id:'threshold',kind:'condition',value:'clearance_threshold',labels:{pt:'TFG <30 mL/min; reavaliar em 24 h',es:'TFG <30 mL/min; reevaluar en 24 h'}};
 r.facts[0].slots.push(slot);r.facts[0].template+=' {{threshold}}';
 const v=validateRecord(r);assert.equal(v.facts[0].slots.filter(s=>s.kind==='quantity').length,3);
 for(const lang of ['pt','es'])assert.ok(renderRecord(v,lang).includes(slot.labels[lang]));
 assert.equal(canonicalFacts(v).facts[0].slots.filter(s=>s.kind==='quantity')[1].value,'<30 mL/min');
 const bad=structuredClone(r);bad.facts[0].slots[2].labels.es=bad.facts[0].slots[2].labels.es.replace('30 mL','30 L');
 assert.throws(()=>validateRecord(bad),/paired_quantity_mismatch/);
});
test('clinical identifier may start with a number and retain a threshold without a translated ID',()=>{
 const r=structuredClone(section);r.facts[0].slots[0].value='12_lead_assessment';r.facts[0].conditionCodes=['onset_≤12h'];assert.doesNotThrow(()=>validateRecord(r));
});

test('strict quantity schema cannot concatenate unit codes into an invented symbol',()=>{
 const {quantityPattern,templatePattern}=require('../plantao_snapshot_schema');
 const quantity=new RegExp(quantityPattern);
 for(const value of ['25 mL VO q12h','500 mg VO','0.1 mcg/kg/min','<30 mL/min','2–3/d','1 x/d'])assert.ok(quantity.test(value),value);
 for(const value of ['25 mg SCl','según protocolo','42 mg cada dia'])assert.ok(!quantity.test(value));
 assert.ok(new RegExp(templatePattern).test('**{{drug}}:** {{amount}}; {{condition}}.'));
 assert.ok(!new RegExp(templatePattern).test('{{drug}} según {{condition}}'));
});

test('typed quantities and implicit canonical slot order cannot omit the PT concept',()=>{
 const r=structuredClone(section);delete r.facts[0].template;
 r.facts[0].slots[1].value=[{kind:'number',value:'42'},{kind:'unit',value:'mg'},{kind:'unit',value:'VO'},{kind:'operator',value:'q'},{kind:'number',value:'12'},{kind:'unit',value:'h'}];
 const v=validateRecord(r);assert.equal(v.facts[0].slots[1].value,'42 mg VO q12 h');
 assert.equal(v.facts[0].template,'{{agent}} {{amount}}');
 for(const lang of ['pt','es'])assert.ok(renderRecord(v,lang).includes(r.facts[0].slots[0].labels[lang]+' 42 mg VO q12 h'));
 const bad=structuredClone(r);bad.facts[0].slots[1].value[2].value='SCl';assert.throws(()=>validateRecord(bad),/invalid_quantity_token/);
});
test('typed threshold and dose range preserve numeric values and operators without calculation',()=>{
 const r=structuredClone(section);delete r.facts[0].template;
 for(const [tokens,expected] of [
  [[{kind:'operator',value:'<'},{kind:'number',value:'30'},{kind:'unit',value:'mL'},{kind:'operator',value:'/'},{kind:'unit',value:'min'}],'<30 mL/min'],
  [[{kind:'number',value:'25'},{kind:'operator',value:'–'},{kind:'number',value:'30'},{kind:'unit',value:'mL'}],'25–30 mL'],
 ]){r.facts[0].slots[1].value=tokens;assert.equal(validateRecord(r).facts[0].slots[1].value,expected);}
});


test('word prefixes are not clinical units during lossless numeric binding',()=>{
 const r=structuredClone(section);
 r.facts[0].slots.push({id:'followup',kind:'relation',value:'followup_count',labels:{pt:'reavaliar em 3 semanas',es:'reevaluar en 3 semanas'}});
 r.facts[0].template+=' {{followup}}';
 const v=validateRecord(r);const q=v.facts[0].slots.filter(s=>s.kind==='quantity').at(-1);
 assert.equal(q.value,'3'); // Must not become 3 s (seconds).
 assert.ok(renderRecord(v,'pt').includes('reavaliar em 3 semanas'));
 assert.ok(renderRecord(v,'es').includes('reevaluar en 3 semanas'));
});
test('wire labels cannot independently regenerate any clinical number',()=>{
 const {snapshotSchema}=require('../plantao_snapshot_schema');
 const factSchema=snapshotSchema().properties.records.items.anyOf[1].properties.facts.items;
 const labels=factSchema.properties.slots.items.anyOf[1].properties.labels;
 for(const lang of ['pt','es']) {
  const pattern=new RegExp(labels.properties[lang].pattern);
  assert.ok(pattern.test('avaliar função renal'));
  for(const value of ['TFG <30 mL/min','500 mg','diabetes tipo 2'])assert.ok(!pattern.test(value));
 }
 const bad=structuredClone(title);bad.labels={pt:'Tipo 1',es:'Tipo 2'};
 assert.throws(()=>validateRecord(bad),/localized_title_value_changed/);
});


test('standalone canonical route is shared without fabricating a numeric dose',()=>{
 const r=structuredClone(section);delete r.facts[0].template;
 r.facts[0].slots[1].value=[{kind:'unit',value:'IV'}];
 const v=validateRecord(r);assert.equal(v.facts[0].slots[1].value,'IV');
 for(const lang of ['pt','es'])assert.ok(renderRecord(v,lang).includes('IV'));
 for(const value of ['q h','por via oral','IV desconhecido']){
   const bad=structuredClone(r);bad.facts[0].slots[1].value=value;
   assert.throws(()=>validateRecord(bad),/quantity_must_be_language_neutral/);
 }
});

test('numeric and unit slots remain shared even when the provider separates them',()=>{
 const r=structuredClone(section);delete r.facts[0].template;
 r.facts[0].slots[1].value=[{kind:'number',value:'42'}];
 r.facts[0].slots.push({id:'unit',kind:'quantity',value:[{kind:'unit',value:'mg'}]});
 const valid=validateRecord(r);
 for(const lang of ['pt','es'])assert.ok(renderRecord(valid,lang).includes('42 mg'));
 assert.equal(valid.facts[0].slots[1].value,'42');
 assert.equal(valid.facts[0].slots[2].value,'mg');
});

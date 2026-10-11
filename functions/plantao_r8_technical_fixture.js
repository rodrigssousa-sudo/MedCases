'use strict';
// Explicit nonclinical UI test. Never selected by pathology/drug queries, never
// used on the public route, and never marks a clinical contract as approved.
const {SnapshotDecoder, VERSION} = require('./plantao_clinical_snapshot');
const {requireHomologation, FLAG_PATH} = require('./plantao_r8_homologation_gate');
function fixtureLanguage(query) {
  return ({'Teste técnico R8':'pt','Prueba técnica R8':'es'})[query] || null;
}
function fixtureRecords() {
  const fact=(id,pt,es)=>({action:'explain',polarity:'affirmative',conceptCodes:[id],conditionCodes:[],slots:[{id,kind:'clinical_concept',value:id,labels:{pt,es}}]});
  return [
    {type:'title',id:'technical_fixture',labels:{pt:'Teste fictício — sem uso clínico',es:'Prueba ficticia — sin uso clínico'}},
    {type:'section',id:'immediate',facts:[fact('inspect','Confira a leitura, a cópia e os identificadores P2Y12, SpO₂, H1N1, IL-6, HbA1c e CD4.','Comprueba la lectura, la copia y los identificadores P2Y12, SpO₂, H1N1, IL-6, HbA1c y CD4.')]},
    {type:'section',id:'treatment',facts:[fact('no_prescription','Nenhum medicamento ou esquema terapêutico foi prescrito neste teste técnico.','No se ha prescrito ningún medicamento ni esquema terapéutico en esta prueba técnica.')]},
    {type:'section',id:'monitoring',facts:[fact('inspect_actions','Teste Ouvir, Dose e Mais. Use somente dados fictícios; não há aprovação clínica deste exemplo.','Prueba Escuchar, Dosis y Más. Usa solo datos ficticios; este ejemplo no tiene aprobación clínica.')]},
    {type:'references',sourceIds:['r8_technical']},
  ];
}
async function technicalFixture({firestore,uid,query,language:requestedLanguage,env=process.env,nowMs}) {
  const queryLanguage=fixtureLanguage(query);
  const language=requestedLanguage || queryLanguage;
  if(!queryLanguage || !['pt','es'].includes(language) || !await requireHomologation({firestore,uid,env,nowMs}))return null;
  const flag=await firestore.doc(FLAG_PATH).get();
  const {authorizeHomologation}=require('./plantao_r8_homologation_gate');
  if(!flag.exists || flag.data().technicalFixtureOnly!==true || !authorizeHomologation(flag.data(),uid,nowMs))return null;
  const sources=[{id:'r8_technical',title:'MedCases R8 — teste técnico de interface, sem referência terapêutica',url:'https://medcasespro.com/support'}];
  const blocks=[];
  const decoder=new SnapshotDecoder({language,sources,framing:'json',onBlock:b=>blocks.push(b)});
  decoder.accept(JSON.stringify({records:fixtureRecords()}));
  return {language,sources,blocks,snapshot:decoder.complete(),answerContract:VERSION};
}
module.exports={fixtureLanguage,technicalFixture};

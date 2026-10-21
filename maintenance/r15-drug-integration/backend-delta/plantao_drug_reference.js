'use strict';
// Uses the existing MCC1 read authority. This is a catalog reference, NEVER a
// prescription, clinical approval, dose calculator or a duplicate drug database.
const crypto=require('node:crypto');
const sha=s=>crypto.createHash('sha256').update(s).digest('hex');
const fail=code=>{throw Object.assign(Error(code),{code});};
const fold=s=>String(s).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[_\s]+/g,' ').trim();
const host='https://plankton-app-9dgnu.ondigitalocean.app';
function labels(row){
 return [row.id,row.name?.pt,row.name?.es,row.pt?.name,row.es?.name,...(Array.isArray(row.keywords)?row.keywords:[])]
  .filter(v=>typeof v==='string').flatMap(v=>[v,...(v.match(/\(([^)]+)\)/)?.[1]?.split(/[,;]/)||[])]).map(fold);
}
function drugLookupIntent(query, contextDrugId) {
 const text=fold(String(query).replace(/^[¿¡\s]+|[?.!]+$/gu,''));
 if(/\b(?:intoxicacao|intoxicacion|intoxication|sobredose|sobredosis|superdose|superdosis|overdose|envenenamento|envenenamiento)\b/u.test(text))return null;
 const fields='contraindicacoes|contraindicaciones|interacoes|interacciones|ajuste renal|ajuste hepatico|diluicao|dilucion|preparo|preparacion|infusao|infusion|apresentacao|presentacion|apresentacoes|presentaciones|mecanismo(?: de acao| de accion)?';
 const prefix='(?:(?:e quanto (?:ao|a|aos|as)|y (?:el|la|los|las))\\s+|(?:quais|cuales)(?: sao| son)?\\s+(?:(?:as|os|las|los)\\s+)?|(?:qual|cual)(?: e| es)?\\s+(?:(?:o|a|el|la)\\s+)?)?';
 const named=new RegExp('^'+prefix+'('+fields+')(?:\\s+(?:de|do|da|del|de la)\\s+(.+))?$','u').exec(text);
 const action=/^como (diluir|preparar|infundir)(?:\s+(?:(?:o|a|el|la)\s+)?(.+))?$/u.exec(text);
 const field=named?.[1]||action?.[1]||null;
 const fieldTopic=named?.[2]||action?.[2]||null;
 const explicit=/^(?:medicamento|farmaco|ficha(?: farmacologica)?)(?: de| del| do| da)?\s+(.+)$/u.exec(text);
 const strength=/^(.+?)\s+(\d+(?:[.,]\d+)?\s*(?:mg|mcg|g|ml))$/u.exec(text);
 const rawTopic=field ? fieldTopic||contextDrugId : explicit?.[1]||strength?.[1]||text;
 if(!rawTopic)return null;
 const topic=require('./gpt_optional_grounding').automaticResearchTopic(rawTopic);
 return topic ? {topic,field,explicit:!!explicit||!!field||!!strength,requestedStrength:strength?.[2]||null} : null;
}
function assertPublishedDrug(raw) {
 const m=raw.mc_gold_standard_v1;
 if(!m||m.status!=='PASS_CLINICAL_HOMOLOGATION'||m.publicationAuthorized!==true||m.requiredFields!==33||
    !/^[a-f0-9]{64}$/.test(m.approvedSha256||'')||typeof m.sourceOwner!=='string'||!m.sourceOwner||
    m.sourceField!==raw.id+'.mcGoldClinicalV1'||m.calculationAuthorized!==false)fail('drug_review_required');
}
function isDrugReferenceRequest(data) {
 // This is a source reference only: never apply patient/history instructions or
 // infer a dose. Identity and permission are re-established by MCC1 below.
 return data&&data.userMessage===data.catalogQuery&&Array.isArray(data.history)&&typeof data.systemPrompt==='string';
}
async function resolveDrugReference({query,language,data,catalogVersion,authorization,contextDrugId=null,fetchImpl=globalThis.fetch}) {
 if(!['pt','es'].includes(language)||!isDrugReferenceRequest(data,catalogVersion))return null;
 const intent=drugLookupIntent(query,contextDrugId);
 if(!intent)return null;
 const {topic}=intent;
 if(!/^Bearer \S+$/.test(authorization||''))fail('drug_catalog_unavailable');
 const issued=await fetchImpl('https://medcasespro.com/api/calculator/session',{method:'POST',headers:{Authorization:authorization,Accept:'application/json','Content-Type':'application/json'},body:'{}',redirect:'error',signal:AbortSignal.timeout(15000)});
 if(!issued.ok)fail(issued.status===403?'permission_denied':'drug_catalog_unavailable');
 const session=await issued.json();
 if(typeof session.accessToken!=='string'||!session.accessToken.startsWith('mcc1.')||session.accessToken.length<16||!['free','premium'].includes(session.tier)||!Array.isArray(session.capabilities)||!(Date.parse(session.expiresAtUtc)>Date.now()))fail('drug_catalog_unavailable');
 const get=async path=>fetchImpl(host+path,{headers:{Authorization:'Bearer '+session.accessToken,Accept:'application/json'},redirect:'error',signal:AbortSignal.timeout(8000)});
 const candidate=fold(topic).replaceAll(' ','_');
 // Exact canonical IDs can be queried by Free without downloading the Premium
 // index. The gateway itself decides the current Free drug allowlist.
 let response=/^[a-z0-9_]+$/.test(candidate)?await get('/api/drugs/'+candidate):null;
 let raw;
 if(response?.ok){const p=await response.json();if(p.ok!==true||p.drug?.id!==candidate)fail('drug_catalog_unavailable');raw=p.drug;}
 else if(response?.status===403)fail('permission_denied');
 else if(response && response.status!==404)fail('drug_catalog_unavailable');
 if(!raw && session.capabilities.includes('drug_catalog_full')){
  const indexResponse=await get('/api/drug-catalog');if(!indexResponse.ok)fail('drug_catalog_unavailable');
  const index=await indexResponse.json();if(index.ok!==true||!Array.isArray(index.drugs))fail('drug_catalog_unavailable');
  const found=index.drugs.filter(row=>labels(row).includes(fold(topic)));
  if(found.length>1)fail('drug_identity_ambiguous');
  if(found.length===1){const id=found[0].id;if(!/^[a-z0-9_]+$/.test(id))fail('drug_catalog_unavailable');response=await get('/api/drugs/'+id);if(!response.ok)fail(response.status===403?'permission_denied':'drug_catalog_unavailable');const p=await response.json();if(p.ok!==true||p.drug?.id!==id)fail('drug_catalog_unavailable');raw=p.drug;}
 }
 if(!raw){if(intent.explicit)fail('drug_not_found');return null;}
 if(!labels(raw).includes(fold(topic)))return null;
 assertPublishedDrug(raw);
 const localized=raw[language];
 if(!localized||typeof localized.name!=='string'||typeof raw.dataVersion!=='string'||!raw.dataVersion||typeof raw.source!=='string'||!raw.source||!(/^[a-f0-9]{64}$/).test(raw.clinicalContentSha256||'')||Buffer.byteLength(JSON.stringify(raw))>250000)fail('drug_source_unavailable');
 const fields=Object.entries(localized).filter(([key,value])=>key!=='name'&&value!==null&&value!==undefined&&value!=='');
 if(!fields.length)fail('drug_source_unavailable');
 // Preserve every localized field verbatim, including dose conditions, safety,
 // limits and source notices. No numeric extraction or calculated derivatives.
 const fieldLabels={name:['Nome','Nombre'],class:['Classe','Clase'],pharmacologicClass:['Classe farmacológica','Clase farmacológica'],mechanism:['Mecanismo','Mecanismo'],pharmacodynamics:['Farmacodinâmica','Farmacodinámica'],pharmacokinetics:['Farmacocinética','Farmacocinética'],indications:['Indicações','Indicaciones'],commercialNames:['Nomes comerciais','Nombres comerciales'],presentation:['Apresentação','Presentación'],presentations:['Apresentações','Presentaciones'],dose:['Posologia de referência','Posología de referencia'],pediatricDose:['Pediatria','Pediatría'],renalDose:['Função renal','Función renal'],hepaticDose:['Função hepática','Función hepática'],commonAdverseEffects:['Efeitos adversos comuns','Efectos adversos comunes'],dangerousAdverseEffects:['Efeitos adversos graves','Efectos adversos graves'],adverseEffects:['Efeitos adversos','Efectos adversos'],contraindications:['Contraindicações','Contraindicaciones'],interactions:['Interações','Interacciones'],monitoring:['Monitorização','Monitorización'],administration:['Administração','Administración'],preparation:['Preparo','Preparación'],infusionProtocol:['Infusão','Infusión'],pregnancy:['Gestação','Embarazo'],lactation:['Lactação','Lactancia'],specialPopulations:['Populações especiais','Poblaciones especiales'],patientEducation:['Orientação','Orientación'],clinicalPearls:['Observações clínicas','Observaciones clínicas'],guidelineRecommendations:['Diretrizes','Guías'],safetyFlags:['Segurança','Seguridad'],alerts:['Alertas','Alertas'],ref:['Referência','Referencia'],references:['Referências','Referencias']};
 const valueText=value=>typeof value==='string'?value:Array.isArray(value)?value.map(valueText).join('\n\n'):value&&typeof value==='object'?Object.entries(value).map(([k,v])=>k+': '+valueText(v)).join('\n\n'):String(value);
 const text='# '+localized.name+'\n\n'+fields.map(([key,value])=>'## '+(fieldLabels[key]?.[language==='pt'?0:1]||key)+'\n\n'+valueText(value)).join('\n\n');
 const document={scope:'CANONICAL_DRUG_INFORMATION_NOT_PRESCRIPTION',language,canonicalDrugId:raw.id,sourceVersion:raw.dataVersion,source:raw.source,sourceContentHash:raw.clinicalContentSha256,sourceJson:JSON.stringify(raw),text,calculationAuthorized:false,clinicalApprovalGranted:false,...(intent.field?{lookupField:intent.field}:{}),...(intent.requestedStrength?{requestedStrength:intent.requestedStrength}:{})};
 const documentJson=JSON.stringify(document);return {documentJson,payloadSha256:sha(documentJson),modelCalls:0};
}
function referenceText(reference,lang){const d=JSON.parse(reference.documentJson);return (lang==='pt'?'Ficha farmacológica — informação de referência, não é prescrição nem autorização de cálculo.':'Ficha farmacológica — información de referencia, no es prescripción ni autorización de cálculo.')+'\n\n'+d.text+'\n\n';}
module.exports={resolveDrugReference,referenceText,labels,isDrugReferenceRequest,drugLookupIntent};

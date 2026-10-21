'use strict';
// Normal endpoint: approved frames with the existing R23 prospective ledger.
const {resolveMedCasesTier}=require('./lib/query_entitlement_source');
const {preserveClinicalPayload}=require('./plantao_r8_transport');
const reject=(code,status=409)=>{throw Object.assign(new Error(code),{code,status});};
async function savedDrugContext(firestore,uid,sessionId) {
 if(typeof sessionId!=='string'||!sessionId||sessionId.includes('/'))return null;
 const parent=await firestore.doc('users/'+uid+'/ai_sessions/'+sessionId).get();
 const data=parent.exists&&parent.data();
 if(!data||data.uid!==uid||data.isDeleted===true||!data.lastRequestId)return null;
 const id=data.lastRequestId;if(typeof id!=='string'||!/^[A-Za-z0-9_-]{1,128}$/.test(id))return null;
 const snapshot=await firestore.doc('users/'+uid+'/ai_sessions/'+sessionId+'/exchanges/'+id).get();
 const exchange=snapshot.exists&&snapshot.data();
 if(!exchange||exchange.uid!==uid||exchange.sessionId!==sessionId||exchange.requestId!==id||exchange.provenance!=='CANONICAL_DRUG_INFORMATION_NOT_PRESCRIPTION')return null;
 const ref=exchange.drugReference;
 if(!ref||typeof ref.documentJson!=='string'||hash(ref.documentJson)!==ref.payloadSha256)return null;
 try {
  const doc=JSON.parse(ref.documentJson);
  if(doc.scope!=='CANONICAL_DRUG_INFORMATION_NOT_PRESCRIPTION'||!['pt','es'].includes(doc.language)||
     !/^[a-z0-9_]+$/.test(doc.canonicalDrugId)||doc.calculationAuthorized!==false||doc.clinicalApprovalGranted!==false||
     exchange.assistantOutput!==require('./plantao_drug_reference').referenceText(ref,doc.language))return null;
  return {canonicalDrugId:doc.canonicalDrugId,requestId:id,payloadSha256:ref.payloadSha256};
 }catch(_){return null;}
}
async function restoreApprovedProtocol({firestore,uid,data,now=Date.now(),external}) {
  const user=await firestore.doc('users/'+uid).get();
  const account=user.exists&&user.data();
  if(!account||account.status!=='approved'||account.accountStatus==='blocked')reject('not_approved',403);
  // Never consume a plan label supplied by Flutter. Expired billing overrides
  // legacy labels exactly as in the existing authoritative entitlement issuer.
  const entitlement=resolveMedCasesTier(account,now);
  if(!['free','premium'].includes(entitlement.tier))reject('permission_denied',403);
  if(data.mode!=='plantao'||data.approvedProtocolAccess!==true||!['pt','es'].includes(data.lang)||
      typeof data.catalogQuery!=='string'||!Array.isArray(data.history))
    reject('clinical_approval_required');
  // Preserve the complete frame before resolving the current remote registry.
  try { preserveClinicalPayload({query:data.userMessage,context:data.systemPrompt,history:data.history}); }
  catch (_) { reject('clinical_approval_required'); }
  let priorDrug=null,drugFailure=null;
  if(external) {
    priorDrug=await savedDrugContext(firestore,uid,data.sessionId);
    try {
      const drugReference=await require('./plantao_drug_reference').resolveDrugReference({
        query:data.catalogQuery,language:data.lang,data,authorization:external.authorization,
        contextDrugId:priorDrug?.canonicalDrugId,fetchImpl:external.fetchImpl,
      });
      if(drugReference)return {drugReference,entitlement,priorDrugRequestId:priorDrug?.requestId||null,
        contextDrugId:priorDrug?.canonicalDrugId||null};
    }catch(error) {
      // A known pending/ambiguous source can never become a pathology or WEB
      // fallback. Dependency/permission failure may still allow an independently
      // authorized clinical protocol; it cannot manufacture catalog absence.
      if(!['permission_denied','drug_catalog_unavailable'].includes(error.code))throw error;
      drugFailure=error;
    }
  }
  if(data.history.length!==0) {
    if(drugFailure)throw drugFailure;
    reject('clinical_approval_required');
  }
  try {
    const {protocol}=await require('./plantao_dynamic_catalog').resolveDynamicProtocol({firestore,data});
    return {protocol,entitlement};
  } catch(error) {
    // Only a valid catalog with no matching identity in BOTH clinical/drug
    // catalogs may enter research. Never translate broken catalog reads to absence.
    if(error.code!=='clinical_approval_required'||!external)throw error;
    if(drugFailure)throw drugFailure;
    const route=await require('./gpt_optional_grounding').resolveResearchRoute({
      query:data.catalogQuery,language:data.lang,firestore,authorization:external.authorization,
      fetchImpl:external.fetchImpl,requireCatalogAbsence:true,
    });
    if(!route||route.reason!=='CATALOG_TOPIC_ABSENT')reject('clinical_approval_required');
    return {researchRoute:route,entitlement};
  }
}
module.exports={restoreApprovedProtocol};

// Reuse the same R23 ledger and existing exchange schema; no second counter.
const {PlantaoQueryLedger,QueryError,hash}=require('./plantao_query_ledger');
const {fullText}=require('./plantao_public_query');
async function deliverApprovedProtocol({firestore,uid,data,verify,alive=()=>true,now=()=>Date.now(),stamp=()=>new Date(),external}) {
  const ledger=new PlantaoQueryLedger({db:firestore,now,prospective:true});
  const fingerprint=hash(JSON.stringify({query:data.userMessage,context:data.systemPrompt,history:data.history,lang:data.lang,catalogQuery:data.catalogQuery}));
  const permit=await ledger.reserve(uid,{requestId:data.requestId,sessionId:data.sessionId,fingerprint});
  let committed=false;
  try {
    const result=await restoreApprovedProtocol({firestore,uid,data,now:now(),external});
    if(!alive())throw new QueryError('REQUEST_REVOKED');
    const auth=await verify();if(auth?.uid!==uid)throw new QueryError('AUTH_REQUIRED');
    const session=firestore.doc('users/'+uid+'/ai_sessions/'+data.sessionId);
    const exchange=session.collection('exchanges').doc(data.requestId);
    if(result.researchRoute) {
      // Existing session ownership must be checked before any paid retrieval.
      // The commit below checks it again, together with current cohort/version.
      const [parent,existing,pointer]=await Promise.all([session.get(),exchange.get(),firestore.doc('app_config/clinical_content').get()]);
      const prior=parent.exists&&parent.data(),c=pointer.exists&&pointer.data();
      if(prior&&(prior.uid!==uid||prior.isDeleted===true||(prior.lastRequestId&&prior.lastRequestId!==data.requestId&&(!result.drugReference||prior.lastRequestId!==result.priorDrugRequestId))))throw new QueryError('SESSION_NOT_EMPTY');
      if(existing.exists)throw new QueryError('PERSISTENCE_CONFLICT');
      if(!c||c.status!=='ACTIVE'||c.activeVersion!==result.researchRoute.activeVersion||c.manifestSha256!==result.researchRoute.manifestSha256)reject('clinical_approval_required');
    }
    if(result.drugReference){
      const current=await require('./plantao_drug_reference').resolveDrugReference({query:data.catalogQuery,language:data.lang,data,contextDrugId:result.contextDrugId,authorization:external.authorization,fetchImpl:external.fetchImpl});
      if(!current||current.payloadSha256!==result.drugReference.payloadSha256)reject('drug_source_unavailable');
    }
    await ledger.transition(uid,permit,'dispatching');
    let research;
    if(result.researchRoute) {
      // Transition and live authorization precede the single provider call.
      research=await require('./gpt_optional_grounding').generalResearch({
        query:data.catalogQuery,language:data.lang,route:result.researchRoute,
        apiKey:external.apiKey(),signal:external.signal,fetchImpl:external.fetchImpl,
      });
      if(!research)reject('external_research_unavailable',503);
      if(!alive())throw new QueryError('REQUEST_REVOKED');
      const currentAuth=await verify();if(currentAuth?.uid!==uid)throw new QueryError('AUTH_REQUIRED');
      const latestRoute=await require('./gpt_optional_grounding').resolveResearchRoute({
        query:data.catalogQuery,language:data.lang,firestore,authorization:external.authorization,
        fetchImpl:external.fetchImpl,requireCatalogAbsence:true,
      });
      if(!latestRoute||latestRoute.reason!=='CATALOG_TOPIC_ABSENT'||latestRoute.activeVersion!==result.researchRoute.activeVersion||latestRoute.manifestSha256!==result.researchRoute.manifestSha256)reject('clinical_approval_required');
    }
    const text=result.drugReference?require('./plantao_drug_reference').referenceText(result.drugReference,data.lang):research?externalText(research.documentJson,data.lang):fullText(result.protocol,data.lang);
    const display=(research||result.drugReference)?null:require('./plantao_executive_display').executiveDisplay(result.protocol,data.lang,text);
    const version=result.protocol||result.researchRoute||result.referenceVersion;

    // No bytes are delivered before this transaction. Commit history and charge
    // together; a disconnected client can recover the answer from History.
    await firestore.runTransaction(async tx=>{
      const opRef=firestore.doc('aiQueryOperations/'+permit.id);
      const [op,user,cfg,parent,existing,catalogPointer]=await Promise.all([tx.get(opRef),tx.get(firestore.doc('users/'+uid)),tx.get(firestore.doc('app_config/plantao_query_migration')),tx.get(session),tx.get(exchange),result.drugReference?Promise.resolve(null):tx.get(firestore.doc('app_config/clinical_content'))]);
      const p=op.data(),account=user.exists&&user.data(),prior=parent.exists&&parent.data();
      if(!result.drugReference&&(!catalogPointer.exists||catalogPointer.data().status!=='ACTIVE'||catalogPointer.data().activeVersion!==version.activeVersion||catalogPointer.data().manifestSha256!==(version.catalogManifestSha256||version.manifestSha256)))throw Object.assign(Error('clinical_approval_required'),{code:'clinical_approval_required'});
      if(!p||p.uid!==uid||p.token!==permit.token||p.state!=='dispatching')throw new QueryError('REQUEST_REPLAY');
      if(!ledger.active(cfg.exists&&cfg.data(),now()))throw new QueryError('MIGRATION_NOT_ACTIVE');
      if(!alive()||!account||account.status!=='approved'||account.accountStatus==='blocked')throw new QueryError('REQUEST_REVOKED');
      if(new Date(p.createdAt).toISOString().slice(0,10)!==new Date(now()).toISOString().slice(0,10))throw new QueryError('REQUEST_REVOKED');
      if(p.tier==='premium'&&resolveMedCasesTier(account,now()).tier!=='premium')throw new QueryError('ENTITLEMENT_CHANGED');
      if(prior&&(prior.uid!==uid||prior.isDeleted===true||(prior.lastRequestId&&prior.lastRequestId!==data.requestId&&(!result.drugReference||prior.lastRequestId!==result.priorDrugRequestId))))throw new QueryError('SESSION_NOT_EMPTY');
      if(existing.exists)throw new QueryError('PERSISTENCE_CONFLICT');
      await ledger.assertCohort(tx,uid);
      const date=stamp();
      tx.set(session,{...(prior||{}),uid,sessionId:data.sessionId,title:data.catalogQuery,mode:'plantao',locale:data.lang,createdAt:prior?.createdAt||date,updatedAt:date,isDeleted:false,schemaVersion:2,lastRequestId:data.requestId});
      // Additive display metadata: never replace immutable full source bytes,
      // and never treat this history field as an independent approval authority.
      tx.set(exchange,{uid,sessionId:data.sessionId,requestId:data.requestId,userInput:data.catalogQuery,userDisplayText:data.catalogQuery,assistantOutput:text,...(display?{assistantDisplayText:display.text,assistantDisplayProvenance:{contentHash:display.contentHash,fullProtocolHash:display.fullProtocolHash,locale:display.locale,sourceVersion:display.sourceVersion}}:{}),...(result.drugReference?{provenance:'CANONICAL_DRUG_INFORMATION_NOT_PRESCRIPTION',drugReference:result.drugReference}:research?{provenance:'EXTERNAL_GENERAL_INFORMATION_NOT_APPROVED_PROTOCOL',externalEvidence:{documentJson:research.documentJson,payloadSha256:research.payloadSha256}}:{provenance:'MEDCASES_APPROVED_PROTOCOL',clinicalProtocol:{owner:result.protocol.owner,version:result.protocol.version,payloadSha256:result.protocol.payloadSha256,activeVersion:result.protocol.activeVersion},...(result.protocol.presentationEnvelope?{clinicalPresentation:result.protocol.presentationEnvelope}:{})}),mode:'plantao',locale:data.lang,createdAt:date,schemaVersion:2});
      tx.set(opRef,{...p,state:'completed',updatedAt:now(),exchangePath:exchange.path,outputHash:hash(text),...(result.drugReference?{provenance:'CANONICAL_DRUG_INFORMATION_NOT_PRESCRIPTION',payloadSha256:result.drugReference.payloadSha256}:research?{provenance:'EXTERNAL_GENERAL_INFORMATION_NOT_APPROVED_PROTOCOL',payloadSha256:research.payloadSha256}:{clinicalOwner:result.protocol.owner,clinicalVersion:result.protocol.version,payloadSha256:result.protocol.payloadSha256})});
    });
    committed=true;
    if(!alive())throw new QueryError('REQUEST_REVOKED');
    return {...result,text,...(research?{research}:{})};
  }catch(error){
    // On an ambiguous commit result, read the operation before refunding.
    // Completed is never refunded; unknown read fails closed for reconciliation.
    if(!committed){const op=await firestore.doc('aiQueryOperations/'+permit.id).get();if(op.exists&&op.data().state==='reserved')await ledger.transition(uid,permit,'refunded');}
    throw error;
  }
}
function externalText(raw,lang){
 const d=JSON.parse(raw);
 const notice=lang==='pt'?'Pesquisa externa — informação geral, não é protocolo homologado nem prescrição individualizada.':'Investigación externa — información general, no es un protocolo homologado ni una prescripción individualizada.';
 return notice+'\n\n'+d.text+'\n\n## '+(lang==='pt'?'Referências':'Referencias')+'\n\n'+d.sources.map(s=>'- ['+s.title+']('+s.url+')').join('\n')+'\n\n';
}
module.exports.externalText=externalText;
function publicError(error){
 if(/^external_research_(?:unavailable_[a-z_]+|requires_clinical_review)$/.test(error.message||'')||/^catalog_discovery_/.test(error.message||''))return {status:503,code:'external_research_unavailable'};

 if(/^clinical_release_/.test(error.message||''))return {status:503,code:'approved_protocol_unavailable'};
 const codes={drug_review_required:[409,'drug_review_required'],drug_not_found:[404,'drug_not_found'],clinical_scope_not_authorized:[409,'clinical_scope_not_authorized'],drug_catalog_unavailable:[503,'drug_catalog_unavailable'],drug_source_unavailable:[409,'drug_source_unavailable'],drug_identity_ambiguous:[409,'drug_identity_ambiguous'],COHORT_DISABLED:[403,'public_test_not_authorized'],COHORT_NOT_AUTHORIZED:[403,'public_test_not_authorized'],FREE_PLANTAO_DAILY_LIMIT_REACHED:[429,'free_plantao_daily_limit_reached'],MIGRATION_NOT_ACTIVE:[503,'public_accounting_not_active'],REQUEST_REPLAY:[409,'request_replay'],REQUEST_CONFLICT:[409,'request_conflict'],INVALID_REQUEST:[400,'invalid_request'],ACCOUNT_REVOKED:[403,'not_approved'],AUTH_REQUIRED:[401,'unauthenticated'],REQUEST_REVOKED:[409,'request_revoked'],ENTITLEMENT_CHANGED:[403,'entitlement_changed'],SESSION_NOT_EMPTY:[409,'session_not_empty'],PERSISTENCE_CONFLICT:[409,'persistence_conflict'],clinical_approval_required:[409,'clinical_approval_required'],not_approved:[403,'not_approved'],permission_denied:[403,'permission_denied']};
 const [status,code]=codes[error.code]||[503,'persistence_unavailable'];return {status,code};
}
module.exports.deliverApprovedProtocol=deliverApprovedProtocol;
module.exports.publicError=publicError;

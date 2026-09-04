"use strict";

const crypto=require("crypto");
const {getApp}=require("firebase-admin/app");
const {getFirestore}=require("firebase-admin/firestore");
const registry=require("./generated/clinical_shadow_observation_s1_registry_index.phase14.local.json");

const SAMPLE_PERCENT=1;

if (
  registry.samplePercent!==1 ||
  registry.patientTextIncluded!==false ||
  registry.providerExecutionEnabled!==false ||
  registry.visibleCutoverEnabled!==false ||
  registry.rows.length!==270
) {
  throw new Error("s1_registry_invalid");
}

const byProtocol=new Map(registry.rows.map(x=>[x.protocolKey,x]));

function s(v){ return typeof v==="string" && v.trim() ? v.trim() : null; }
function body(req){ return req && req.body && typeof req.body==="object" && !Array.isArray(req.body) ? req.body : {}; }
function machine(req,key){
  const b=body(req);
  const d=b.data && typeof b.data==="object" && !Array.isArray(b.data) ? b.data : {};
  const c=b.clinicalContext && typeof b.clinicalContext==="object" && !Array.isArray(b.clinicalContext) ? b.clinicalContext : {};
  const i=b.clinicalIdentity && typeof b.clinicalIdentity==="object" && !Array.isArray(b.clinicalIdentity) ? b.clinicalIdentity : {};
  return s(b[key]) || s(d[key]) || s(c[key]) || s(i[key]);
}
function trace(req){
  const h=req && req.headers && typeof req.headers==="object" ? req.headers : {};
  const x=s(h["x-cloud-trace-context"]) || s(h["x-request-id"]) || s(h["traceparent"]);
  return x ? x.split("/")[0].split(";")[0] : null;
}
function hash16(v){ return v ? crypto.createHash("sha256").update(String(v)).digest("hex").slice(0,16) : null; }
function bucket(v){ if(!v) return null; return crypto.createHash("sha256").update(v).digest().readUInt32BE(0)%100; }

function createClinicalShadowObservationS1Runtime(){
  async function observeFromRequest(req){
    const t=trace(req);
    const b=bucket(t);
    if (b===null || b>=SAMPLE_PERCENT) {
      return Object.freeze({observed:false,sampled:false,providerCalls:0,visibleMutation:false});
    }

    const protocolKey=machine(req,"protocolKey");
    const pathologyKey=machine(req,"canonicalPathologyKey");
    const row=protocolKey ? byProtocol.get(protocolKey) : null;

    if(!row){
      const observation=Object.freeze({
        event:"clinical_shadow_observation_s1",
        samplePercent:1,
        requestIdHash:hash16(t),
        protocolKeyHash:hash16(protocolKey),
        pathologyKeyHash:hash16(pathologyKey),
        registryRowResolved:false,
        identityResolved:false,
        protocolResolved:false,
        machineActionReady:false,
        machineContentReady:false,
        identityMismatch:false,
        protocolMismatch:false,
        missingMachineAction:true,
        missingMachineContent:true,
        patientTextCaptured:false,
        providerCalls:0,
        visibleMutation:false,
        errorCode:protocolKey ? "registry_row_not_found" : "protocol_key_missing",
      });
      console.info("CLINICAL_SHADOW_OBSERVATION_S1",JSON.stringify(observation));
      return Object.freeze({observed:true,sampled:true,observation,providerCalls:0,visibleMutation:false});
    }

    let snaps;
    try {
      const db=getFirestore(getApp());
      snaps=await db.getAll(
        db.collection(row.identity.collection).doc(row.identity.documentId),
        db.collection(row.protocol.collection).doc(row.protocol.documentId),
        db.collection(row.primaryAction.collection).doc(row.primaryAction.documentId),
        db.collection(row.protocolContent.collection).doc(row.protocolContent.documentId),
      );
    } catch(error){
      const observation=Object.freeze({
        event:"clinical_shadow_observation_s1",
        samplePercent:1,
        requestIdHash:hash16(t),
        protocolKeyHash:hash16(protocolKey),
        pathologyKeyHash:hash16(pathologyKey),
        registryRowResolved:true,
        identityResolved:false,
        protocolResolved:false,
        machineActionReady:false,
        machineContentReady:false,
        identityMismatch:false,
        protocolMismatch:false,
        missingMachineAction:true,
        missingMachineContent:true,
        patientTextCaptured:false,
        providerCalls:0,
        visibleMutation:false,
        errorCode:s(error && error.code) || "observer_error",
      });
      console.info("CLINICAL_SHADOW_OBSERVATION_S1",JSON.stringify(observation));
      return Object.freeze({observed:true,sampled:true,observation,providerCalls:0,visibleMutation:false});
    }

    const [idSnap,pSnap,aSnap,cSnap]=snaps;
    const idData=idSnap.exists ? idSnap.data() : null;
    const pData=pSnap.exists ? pSnap.data() : null;

    const identityMismatch=Boolean(idData && pathologyKey && idData.canonicalKey!==pathologyKey);
    const protocolMismatch=Boolean(
      pData && (
        pData.protocolKey!==protocolKey ||
        (pathologyKey && pData.canonicalPathologyKey!==pathologyKey)
      )
    );

    const observation=Object.freeze({
      event:"clinical_shadow_observation_s1",
      samplePercent:1,
      requestIdHash:hash16(t),
      protocolKeyHash:hash16(protocolKey),
      pathologyKeyHash:hash16(pathologyKey),
      registryRowResolved:true,
      identityResolved:idSnap.exists,
      protocolResolved:pSnap.exists,
      machineActionReady:aSnap.exists,
      machineContentReady:cSnap.exists,
      identityMismatch,
      protocolMismatch,
      missingMachineAction:!aSnap.exists,
      missingMachineContent:!cSnap.exists,
      patientTextCaptured:false,
      providerCalls:0,
      visibleMutation:false,
      errorCode:null,
    });

    console.info("CLINICAL_SHADOW_OBSERVATION_S1",JSON.stringify(observation));
    return Object.freeze({observed:true,sampled:true,observation,providerCalls:0,visibleMutation:false});
  }

  return Object.freeze({
    schemaVersion:"clinical_shadow_observation_s1_runtime_v3_lazy_admin_init",
    samplePercent:1,
    providerExecutionEnabled:false,
    patientTextCaptureEnabled:false,
    visibleCutoverEnabled:false,
    observeFromRequest,
  });
}

module.exports={createClinicalShadowObservationS1Runtime};

"use strict";

const assert=require("assert");

const m41=require(
  "../clinical_context/generated/clinical_machine_classifications.m41_01.local.json"
);
const m43=require(
  "../clinical_context/generated/clinical_machine_classifications.m43_02.local.json"
);
const consolidated=require(
  "../clinical_context/generated/clinical_machine_classifications.consolidated94.phase17.local.json"
);
const supplement=require(
  "../clinical_context/generated/clinical_registry_machine_native_supplement.phase17_classification94.local.json"
);
const {
  ClinicalClassificationResolver,
}=require("../clinical_context/clinical_classification_resolver");

assert.strictEqual(m41.records.length,47);
assert.strictEqual(m43.records.length,47);
assert.strictEqual(consolidated.records.length,94);

assert.strictEqual(m43.machineEvaluableCount,8);
assert.strictEqual(m43.noncanonicalFailClosedCount,39);
assert.strictEqual(consolidated.machineEvaluableCount,40);
assert.strictEqual(consolidated.noncanonicalFailClosedCount,54);
assert.strictEqual(consolidated.managementReadyCount,0);
assert.strictEqual(consolidated.visibleCutoverEligibleCount,0);

const protocolKeys=consolidated.records.map(x=>x.protocolKey);
const pathologyKeys=consolidated.records.map(x=>x.canonicalPathologyKey);

assert.strictEqual(new Set(protocolKeys).size,94);
assert.strictEqual(new Set(pathologyKeys).size,94);

assert.strictEqual(supplement.classifications.length,94);
assert.strictEqual(supplement.managementRules.length,0);
assert.strictEqual(supplement.cloudWriteAuthorized,false);
assert.strictEqual(supplement.shadowS1Percent,1);
assert.strictEqual(supplement.shadowPercentChangeAuthorized,false);
assert.strictEqual(supplement.visibleCutover,false);

const expectedM43Enabled=new Set([
  "intox_digoxina_glicosideos",
  "intox_litio",
  "intox_paracetamol",
  "intox_salicilatos",
  "lesao_renal_aguda",
  "pneumonia_grave",
  "tep_agudo",
  "tromboembolismo_pulmonar",
]);

const enabledM43=new Set(
  m43.records.filter(x=>x.enabled===true).map(x=>x.canonicalPathologyKey)
);

assert.deepStrictEqual(
  [...enabledM43].sort(),
  [...expectedM43Enabled].sort(),
);

for (const row of m43.records) {
  assert.strictEqual(row.clinicalSemanticInferencePerformed,false);
  assert.strictEqual(row.managementReady,false);
  assert.strictEqual(row.visibleCutoverEligible,false);
  assert.strictEqual(
    row.provenancePolicy,
    "AUTHORITATIVE_CURRENT_OR_FAIL_CLOSED",
  );
  assert(row.labels && row.labels.pt && row.labels.es);
  assert(row.explanation && row.explanation.pt && row.explanation.es);
  assert(row.sourceEvidence);
  assert.strictEqual(
    row.sourceEvidence.legacyPromotedAutomatically,
    false,
  );

  if (row.enabled===true) {
    assert.strictEqual(
      row.authoringStatus,
      "VALIDATED_CANONICAL_LOCAL_DRAFT",
    );
    assert(Array.isArray(row.categories) && row.categories.length>0);
    assert(Array.isArray(row.provenance) && row.provenance.length>0);
    for (const p of row.provenance) {
      assert(/^https:\/\//.test(String(p.url||"")));
    }
  } else {
    assert.strictEqual(row.authoringStatus,"NONCANONICAL_FAIL_CLOSED");
    assert.strictEqual(
      row.resolutionPolicy,
      "disabled_noncanonical_fail_closed",
    );
    assert.strictEqual((row.categories||[]).length,0);
    assert(row.legacyDisplayContent);
  }
}

const byPathology=new Map(
  m43.records.map(x=>[x.canonicalPathologyKey,x])
);
const resolver=new ClinicalClassificationResolver();

function resolve(pathologyKey,patientFacts) {
  return resolver.resolve({
    pathologyKey,
    descriptors:[byPathology.get(pathologyKey)],
    patientFacts,
  });
}

let r;

r=resolve("tromboembolismo_pulmonar",{
  pe:{incidental:true,symptomatic:false},
});
assert.strictEqual(r.resolved,true);
assert.strictEqual(r.categoryKey,"a");

r=resolve("tromboembolismo_pulmonar",{
  pe:{
    symptomatic:true,
    elevatedClinicalSeverityScore:true,
    rvAbnormal:true,
    biomarkerAbnormal:true,
  },
});
assert.strictEqual(r.resolved,true);
assert.strictEqual(r.categoryKey,"c3");

r=resolve("tep_agudo",{
  pe:{cardiacArrest:true},
});
assert.strictEqual(r.resolved,true);
assert.strictEqual(r.categoryKey,"e2_cardiac_arrest");
assert.strictEqual(r.categoryPayload.canonicalCategoryKey,"e2");

r=resolve("lesao_renal_aguda",{
  aki:{creatinineRatioBaseline:3.2},
});
assert.strictEqual(r.resolved,true);
assert.strictEqual(r.categoryKey,"stage_3_creatinine_ratio");
assert.strictEqual(r.categoryPayload.canonicalCategoryKey,"stage_3");

r=resolve("pneumonia_grave",{
  cap:{
    invasiveMechanicalVentilation:false,
    septicShockVasopressor:false,
    minorCriteriaCount:3,
  },
});
assert.strictEqual(r.resolved,true);
assert.strictEqual(r.categoryKey,"severe_minor_criteria");
assert.strictEqual(r.categoryPayload.canonicalCategoryKey,"severe");

r=resolve("intox_paracetamol",{
  apap:{
    historyReliable:true,
    ingestionDurationHours:1,
    hoursSinceFirstIngestion:6,
    aboveHighRiskNomogramLine:true,
    aboveTreatmentNomogramLine:true,
  },
});
assert.strictEqual(r.resolved,true);
assert.strictEqual(r.categoryKey,"acute_high_risk");

r=resolve("intox_paracetamol",{
  apap:{
    historyReliable:true,
    ingestionDurationHours:30,
    hoursSinceFirstIngestion:30,
  },
});
assert.strictEqual(r.resolved,true);
assert.strictEqual(r.categoryKey,"repeated_supratherapeutic");

r=resolve("intox_litio",{
  lithium:{acuteIngestion:true,chronicUse:true},
});
assert.strictEqual(r.resolved,true);
assert.strictEqual(r.categoryKey,"acute_on_chronic");

r=resolve("intox_digoxina_glicosideos",{
  digoxin:{acuteIngestion:false,chronicUse:true},
});
assert.strictEqual(r.resolved,true);
assert.strictEqual(r.categoryKey,"chronic");

r=resolve("intox_salicilatos",{
  salicylate:{acuteIngestion:true,chronicUse:false},
});
assert.strictEqual(r.resolved,true);
assert.strictEqual(r.categoryKey,"acute");

r=resolve("tep_agudo",{
  pe:{refractoryCardiogenicShock:true},
});
assert.strictEqual(r.resolved,true);
assert.strictEqual(r.categoryKey,"e2_refractory_shock");
assert.strictEqual(r.categoryPayload.canonicalCategoryKey,"e2");

r=resolve("lesao_renal_aguda",{
  aki:{rrtInitiated:true},
});
assert.strictEqual(r.resolved,true);
assert.strictEqual(r.categoryKey,"stage_3_rrt");
assert.strictEqual(r.categoryPayload.canonicalCategoryKey,"stage_3");

r=resolve("pneumonia_grave",{
  cap:{
    invasiveMechanicalVentilation:true,
    septicShockVasopressor:false,
    minorCriteriaCount:0,
  },
});
assert.strictEqual(r.resolved,true);
assert.strictEqual(r.categoryKey,"severe_imv");
assert.strictEqual(r.categoryPayload.canonicalCategoryKey,"severe");

const disabled=m43.records.find(x=>x.enabled!==true);
assert(disabled);
r=resolver.resolve({
  pathologyKey:disabled.canonicalPathologyKey,
  descriptors:[disabled],
  patientFacts:{},
});
assert.strictEqual(r.resolved,false);

console.log("M43_CONTRACT=PASS");
console.log("M43_PROTOCOLS=47/47");
console.log("M43_MACHINE_EVALUABLE_ENABLED=8/47");
console.log("M43_NONCANONICAL_FAIL_CLOSED=39/47");
console.log("M43_RESOLVER_COMPAT_PURE_OR_EXPANSION=PASS");
console.log("M43_REPRESENTATIVE_RESOLVER_CASES=14/14_PASS");
console.log("GLOBAL_CLASSIFICATION_RECORDS=94/94");
console.log("GLOBAL_MACHINE_EVALUABLE=40/94");
console.log("GLOBAL_FAIL_CLOSED=54/94");
console.log("GLOBAL_PROTOCOL_UNIQUENESS=94/94_PASS");
console.log("GLOBAL_PATHOLOGY_UNIQUENESS=94/94_PASS");
console.log("GLOBAL_MANAGEMENT_READY=0/94");
console.log("GLOBAL_VISIBLE_CUTOVER=HARD_OFF");

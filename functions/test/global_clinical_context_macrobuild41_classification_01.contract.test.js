"use strict";

const assert=require("assert");

const authored=require(
  "../clinical_context/generated/clinical_machine_classifications.m41_01.local.json"
);
const supplement=require(
  "../clinical_context/generated/clinical_registry_machine_native_supplement.phase15_m41.local.json"
);
const {
  ClinicalClassificationResolver,
}=require("../clinical_context/clinical_classification_resolver");

const records=authored.records;

assert.strictEqual(records.length,47);
assert.strictEqual(new Set(records.map(x=>x.canonicalPathologyKey)).size,47);
assert.strictEqual(new Set(records.map(x=>x.classificationKey)).size,47);

const enabled=records.filter(x=>x.enabled===true);
const disabled=records.filter(x=>x.enabled!==true);

assert.strictEqual(enabled.length,32);
assert.strictEqual(disabled.length,15);
assert.strictEqual(authored.machineEvaluableCount,32);
assert.strictEqual(authored.noncanonicalFailClosedCount,15);
assert.strictEqual(authored.managementReadyCount,0);
assert.strictEqual(authored.visibleCutoverEligibleCount,0);

assert.strictEqual(supplement.cloudWriteAuthorized,false);
assert.strictEqual(supplement.shadowS1Percent,1);
assert.strictEqual(supplement.shadowPercentChangeAuthorized,false);
assert.strictEqual(supplement.visibleCutover,false);
assert.strictEqual(supplement.managementRules.length,0);

for (const row of records) {
  for (const key of [
    "classificationKey",
    "canonicalPathologyKey",
    "mode",
    "enabled",
    "priority",
    "version",
  ]) {
    assert(
      Object.prototype.hasOwnProperty.call(row,key),
      `required_key_missing:${row.canonicalPathologyKey}:${key}`,
    );
  }

  assert(["categorical","score","stage"].includes(row.mode));
  assert.strictEqual(row.clinicalSemanticInferencePerformed,false);
  assert.strictEqual(row.managementReady,false);
  assert.strictEqual(row.visibleCutoverEligible,false);
  assert.strictEqual(
    row.provenancePolicy,
    "AUTHORITATIVE_CURRENT_OR_FAIL_CLOSED",
  );
  assert(Array.isArray(row.provenance) && row.provenance.length>0);
  for (const p of row.provenance) {
    assert(/^https:\/\//.test(String(p.url||"")));
  }
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
    if (row.mode==="score") {
      assert(Array.isArray(row.components) && row.components.length>0);
      assert(Array.isArray(row.bands) && row.bands.length>0);
    } else {
      assert(Array.isArray(row.categories) && row.categories.length>0);
      for (const category of row.categories) {
        assert(category.payload);
        assert(category.payload.meaning);
        assert(category.payload.meaning.pt);
        assert(category.payload.meaning.es);
      }
    }
  } else {
    assert.strictEqual(row.authoringStatus,"NONCANONICAL_FAIL_CLOSED");
    assert.strictEqual(
      row.resolutionPolicy,
      "disabled_noncanonical_fail_closed",
    );
    assert.strictEqual((row.categories||[]).length,0);
    assert.strictEqual((row.components||[]).length,0);
    assert.strictEqual((row.bands||[]).length,0);
  }
}

const byPathology=new Map(
  records.map(x=>[x.canonicalPathologyKey,x])
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

r=resolve("hiperpotassemia_grave",{
  electrolytes:{potassiumMmolL:6.6},
});
assert.strictEqual(r.resolved,true);
assert.strictEqual(r.categoryKey,"severe");

r=resolve("hipoglicemia_grave",{
  glucose:{mgDl:50},
  hypoglycemia:{requiresAssistance:false},
});
assert.strictEqual(r.resolved,true);
assert.strictEqual(r.categoryKey,"level_2");

r=resolve("iam_congestao",{
  mi:{
    cardiogenicShock:false,
    pulmonaryEdema:false,
    heartFailureSigns:true,
  },
});
assert.strictEqual(r.resolved,true);
assert.strictEqual(r.categoryKey,"killip_ii");
assert(r.categoryPayload.meaning.pt.includes("Killip II"));

r=resolve("iam_supra",{
  mi:{
    procedureRelated:false,
    supplyDemandMismatch:true,
    primaryCoronaryEvent:false,
  },
});
assert.strictEqual(r.resolved,true);
assert.strictEqual(r.categoryKey,"secondary");

r=resolve("choque_cardiogenico",{
  shock:{
    extremis:false,
    deteriorating:false,
    hypoperfusion:true,
    hemodynamicInstability:true,
    atRisk:true,
  },
});
assert.strictEqual(r.resolved,true);
assert.strictEqual(r.categoryKey,"C");

r=resolve("crise_hipertensiva",{
  bp:{systolic:190,diastolic:100},
  hypertension:{acuteTargetOrganDamage:true},
});
assert.strictEqual(r.resolved,true);
assert.strictEqual(r.categoryKey,"hypertensive_emergency");

r=resolve("dengue_manejo",{
  dengue:{
    severeCriteria:false,
    warningSigns:true,
  },
});
assert.strictEqual(r.resolved,true);
assert.strictEqual(r.categoryKey,"dengue_with_warning_signs");

r=resolve("cetoacidose_diabetica",{
  dka:{betaHydroxybutyrateMmolL:7},
  blood:{pH:6.9,bicarbonateMmolL:8},
  neurology:{mentalStatus:"coma"},
});
assert.strictEqual(r.resolved,true);
assert.strictEqual(r.categoryKey,"severe");
assert.strictEqual(r.categoryPayload.severityBand,"severe");

r=resolve("avc_hemorragico",{
  neurology:{gcs:4},
  age:80,
  ich:{
    volumeMl:35,
    intraventricular:true,
    infratentorial:true,
  },
});
assert.strictEqual(r.resolved,true);
assert.strictEqual(r.score,6);
assert.strictEqual(r.categoryKey,"ich_score_6");

r=resolve("coagulacao_intravascular",{
  dic:{
    platelets10e9L:40,
    dDimerXuln:8,
    ptProlongationSeconds:7,
    fibrinogenGL:0.8,
  },
});
assert.strictEqual(r.resolved,true);
assert.strictEqual(r.score,8);
assert.strictEqual(r.categoryKey,"overt_dic");

r=resolve("anafilaxia",{});
assert.strictEqual(r.resolved,false);
assert.strictEqual(r.reason,"classification_not_registered");

console.log("M41_CLASSIFICATION_CONTRACT=PASS");
console.log("M41_REQUIRED_SCHEMA_KEYS=PASS");
console.log("M41_PT_ES_LABEL_EXPLANATION_PARITY=PASS");
console.log("M41_PROVENANCE_HTTPS=PASS");
console.log("M41_MACHINE_EVALUABLE_ENABLED=32");
console.log("M41_NONCANONICAL_FAIL_CLOSED=15");
console.log("M41_REPRESENTATIVE_RESOLVER_CASES=11/11_PASS");
console.log("M41_KILLIP_MEANING_PAYLOAD=PASS");
console.log("M41_FIFTH_UDMI_2026_SECONDARY_MI=PASS");
console.log("M41_DKA_DSL_BRANCHING=PASS");
console.log("M41_NO_VISIBLE_CUTOVER=PASS");

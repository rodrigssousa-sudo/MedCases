"use strict";

const assert = require("assert");

const {
  ClinicalCaseIdentityResolver,
} = require("../clinical_context/clinical_case_identity_resolver");
const {
  ClinicalProtocolMatcher,
} = require("../clinical_context/clinical_protocol_matcher");

const identities = [
  {
    canonicalKey: "tep_agudo",
    displayLabel: "Tromboembolismo pulmonar",
    aliases: [
      "TEP",
      "embolia pulmonar",
      "tromboembolismo pulmonar",
      "tromboembolia pulmonar",
      "pulmonary embolism",
    ],
    strongAliases: ["TEP"],
  },
  {
    canonicalKey: "iam",
    displayLabel: "Infarto agudo do miocárdio",
    aliases: [
      "IAM",
      "infarto agudo do miocardio",
      "infarto agudo de miocardio",
      "myocardial infarction",
    ],
    strongAliases: ["IAM"],
  },
  {
    canonicalKey: "pneumonia",
    displayLabel: "Pneumonia",
    aliases: [
      "pneumonia",
      "neumonia",
      "community acquired pneumonia",
    ],
  },
];

const resolver = new ClinicalCaseIdentityResolver();

{
  const x = resolver.resolve({
    input: "Qual o tratamento do TEP neste paciente?",
    descriptors: identities,
  });
  assert.strictEqual(x.canonicalKey, "tep_agudo");
  assert.strictEqual(x.isHighConfidence, true);
}

{
  const x = resolver.resolve({
    input: "¿Cuál es el tratamiento de la embolia pulmonar?",
    descriptors: identities,
  });
  assert.strictEqual(x.canonicalKey, "tep_agudo");
  assert.strictEqual(x.ambiguous, false);
}

{
  const x = resolver.resolve({
    input: "¿Y el tratamiento?",
    activeCaseAnchor: "Caso activo: tromboembolismo pulmonar",
    descriptors: identities,
  });
  assert.strictEqual(x.canonicalKey, "tep_agudo");
}

{
  const x = resolver.resolve({
    input: "Conduta para este caso completamente inespecífico",
    descriptors: identities,
  });
  assert.strictEqual(x.canonicalKey, "");
  assert.strictEqual(x.ambiguous, false);
}

const protocols = [
  {
    protocolKey: "tep_legacy_low_priority",
    canonicalPathologyKey: "tep_agudo",
    priority: 1,
    enabled: true,
    payload: "legacy",
  },
  {
    protocolKey: "tep_2026_aha_acc",
    canonicalPathologyKey: "tep_agudo",
    priority: 100,
    enabled: true,
    payload: "AHA_ACC_2026",
  },
  {
    protocolKey: "iam_current",
    canonicalPathologyKey: "iam",
    priority: 100,
    enabled: true,
    payload: "IAM_CURRENT",
  },
];

const matcher = new ClinicalProtocolMatcher();

{
  const x = matcher.match({
    input: "tratamiento del TEP",
    identities,
    protocols,
  });
  assert.strictEqual(x.found, true);
  assert.strictEqual(x.protocol.protocolKey, "tep_2026_aha_acc");
  assert.strictEqual(x.protocol.payload, "AHA_ACC_2026");
}

{
  const x = matcher.match({
    input: "TEP",
    identities,
    protocols: [
      {
        protocolKey: "tep_a",
        canonicalPathologyKey: "tep_agudo",
        priority: 100,
        enabled: true,
      },
      {
        protocolKey: "tep_b",
        canonicalPathologyKey: "tep_agudo",
        priority: 100,
        enabled: true,
      },
    ],
  });
  assert.strictEqual(x.found, false);
  assert.strictEqual(x.ambiguous, true);
  assert.strictEqual(x.reason, "protocol_priority_tie");
}

console.log("REMOTE_BUILD1_R1_CONTRACT_TEST=PASS");
console.log("REMOTE_BUILD1_R1_TEST_COUNT=6");

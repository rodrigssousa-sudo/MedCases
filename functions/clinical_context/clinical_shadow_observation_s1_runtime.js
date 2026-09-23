"use strict";

const {
  createShadowObservationCanaryRuntime,
} = require("./clinical_shadow_observation_canary_runtime");

// S1's historical Phase14 registry has no recoverable provenance. Decommission
// observation explicitly; do not substitute clinical data or activate Phase24.
// Keep the async handler seam while using the existing fail-closed runtime.
function createClinicalShadowObservationS1Runtime() {
  const disabled = createShadowObservationCanaryRuntime({
    shadowObservationEnabled: false,
    providerExecutionEnabled: false,
    firebaseReadEnabled: false,
  });
  return Object.freeze({
    schemaVersion: "clinical_shadow_observation_s1_decommissioned_v1",
    shadowObservationEnabled: false,
    providerExecutionEnabled: false,
    firebaseReadEnabled: false,
    patientTextCaptureEnabled: false,
    visibleCutoverEnabled: false,
    visibleMutation: false,
    samplePercent: 0,
    // Do not read or retain the request, including getters or clinical text.
    observeFromRequest: async () => disabled.observe(),
  });
}

module.exports = { createClinicalShadowObservationS1Runtime };

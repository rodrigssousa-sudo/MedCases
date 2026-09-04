"use strict";

function createSyntheticClinicalProviderStub({
  mode = "success",
  onCall,
} = {}) {
  const executor = async function syntheticClinicalProviderStub(
    request,
  ) {
    if (typeof onCall === "function") {
      onCall(request);
    }

    if (mode === "throw") {
      throw new Error("synthetic_provider_stub_failure");
    }

    return Object.freeze({
      handled: true,
      committed: true,
      status: "committed",
      disposition: "committed",
      synthetic: true,
      response: Object.freeze({
        schemaVersion: "clinical_response_v1",
        finalText: "SYNTHETIC_HIDDEN_REMOTE_OUTPUT",
        actions: Object.freeze([
          Object.freeze({
            kind: "primary",
            actionType: "dispatch_prompt",
          }),
        ]),
      }),
    });
  };

  Object.defineProperty(
    executor,
    "__clinicalContextSyntheticProviderStub",
    {
      value: true,
      enumerable: false,
      writable: false,
      configurable: false,
    },
  );

  return executor;
}

module.exports = {
  createSyntheticClinicalProviderStub,
};

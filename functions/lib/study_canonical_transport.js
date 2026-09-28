"use strict";
const schema = require("./study_canonical_schema_v1.json");
const VERSION = "study_clinical_snapshot_v1";
const MARKER = "STUDY CANONICAL TRANSPORT v1";

// Serialization-only opt-in after existing endpoint authorization/quota gates.
// No model, role, entitlement, provider selection or accounting is changed.
function studyCanonicalTransport(body) {
  if (body?.mode !== "estudo" || body?.provider === "openai" ||
      body?.studyCanonicalVersion !== VERSION ||
      typeof body?.systemPrompt !== "string" ||
      !body.systemPrompt.trimStart().startsWith(MARKER)) return null;
  return {
    version: VERSION,
    maxOutputTokens: 32768,
    generationConfig: {responseMimeType: "application/json", responseJsonSchema: schema},
  };
}
module.exports = {studyCanonicalTransport, VERSION};

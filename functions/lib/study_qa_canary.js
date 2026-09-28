"use strict";
// Caller must have verified the Firebase token first. Disabled without a bounded window.
const EXPECTED_QA_UID = "Wa1AQN8hvCdewLiR2drd01rQo9G3";
function studyQaCanaryAllowed({uid, endpoint, body, start, until, now = Date.now()}) {
  const from = Date.parse(start), to = Date.parse(until);
  return uid === EXPECTED_QA_UID && endpoint === "geminiPaidProxy" &&
    body?.mode === "estudo" && body?.provider !== "openai" &&
    body?.studyCanonicalVersion === "study_clinical_snapshot_v1" &&
    typeof body?.systemPrompt === "string" &&
    body.systemPrompt.trimStart().startsWith("STUDY CANONICAL TRANSPORT v1") &&
    Number.isFinite(from) && Number.isFinite(to) && Number.isFinite(now) &&
    to > from && to - from <= 2 * 60 * 60 * 1000 && now >= from && now < to;
}
module.exports = {studyQaCanaryAllowed};

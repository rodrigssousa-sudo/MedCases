"use strict";
const {createHash} = require("node:crypto");
const FLAG_PATH = "app_config/plantao_r8_homologation";
const CONTRACT = "PLANTAO_PRESENTATION_CONTRACT_V2";
// Separate test endpoint only. Never grants approval, tier or quota privileges.
// Read per request: disabling the flag immediately rejects NEW requests.
function authorizeHomologation(config, uid, nowMs = Date.now()) {
  if (!config || config.enabled !== true || config.contract !== CONTRACT) return false;
  if (!Number.isSafeInteger(config.expiresAtMs) || config.expiresAtMs <= nowMs) return false;
  if (typeof uid !== "string" || !uid || !Array.isArray(config.allowedUidHashes)) return false;
  const digest = createHash("sha256").update(uid).digest("hex");
  return config.allowedUidHashes.length === 1 && config.allowedUidHashes[0] === digest;
}
async function requireHomologation({firestore, uid, env = process.env, nowMs}) {
  if (env.PLANTAO_R8_ISOLATED !== "true") return false;
  try {
    const doc = await firestore.doc(FLAG_PATH).get();
    return doc.exists && authorizeHomologation(doc.data(), uid, nowMs);
  } catch (_) { return false; }
}
module.exports = {FLAG_PATH, CONTRACT, authorizeHomologation, requireHomologation};

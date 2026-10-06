'use strict';
// This adjusts only source-based full-summary delivery. It grants no entitlement
// and leaves canonical Study chat, Plantao and other utility consumers intact.
function utilityOutputBudget(body, canonicalBudget) {
  if (canonicalBudget != null) return canonicalBudget;
  const requested = Number(body?.maxOutputTokens);
  const value = Number.isFinite(requested) ? requested : 800;
  const fullSummary = body?.mode === 'estudo' &&
    body?.studyFullSummaryVersion === 'study-full-summary-v1';
  if (!fullSummary) return Math.min(Math.max(Number(body?.maxOutputTokens) || 800, 200), 2048);
  return Math.trunc(Math.min(Math.max(value || 800, 200), 8192));
}
module.exports = {utilityOutputBudget};

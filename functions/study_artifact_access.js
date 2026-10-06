'use strict';
const clean = value => String(value ?? '').trim();
const normalized = value => clean(value).toLowerCase();
function resolveMedCasesTier(userDoc = {}, nowMs = Date.now()) {
  const plan = normalized(userDoc.plan);
  const subscriptionStatus = normalized(userDoc.subscriptionStatus);

  const premiumByPlan =
    plan === 'premium' ||
    plan === 'pro' ||
    plan === 'paid';

  const premiumBySubscription =
    subscriptionStatus === 'active' ||
    subscriptionStatus === 'premium' ||
    subscriptionStatus === 'paid';

  const billingExpiresAtMs = Number(userDoc.billingEntitlementExpiresAtMs ?? 0);
  const premiumByRevenueCat =
    userDoc.billingEntitlementActive === true &&
    clean(userDoc.billingEntitlementId) === 'medcases_pro_premium' &&
    Number.isFinite(billingExpiresAtMs) &&
    billingExpiresAtMs > Number(nowMs);

  // An explicit billing record takes precedence over stale legacy plan labels.
  // Active trials and cancelled-but-unexpired periods share this same decision.
  const hasBillingRecord = Object.prototype.hasOwnProperty.call(userDoc, 'billingEntitlementActive') ||
    Object.prototype.hasOwnProperty.call(userDoc, 'billingEntitlementId') ||
    Object.prototype.hasOwnProperty.call(userDoc, 'billingEntitlementExpiresAtMs');
  if (hasBillingRecord && !premiumByRevenueCat) {
    return Object.freeze({ tier: 'free', source: 'server_billing_inactive_or_expired' });
  }
  if (premiumByRevenueCat || premiumByPlan || premiumBySubscription) {
    return Object.freeze({
      tier: 'premium',
      source: premiumByRevenueCat
        ? 'server_revenuecat_entitlement'
        : premiumByPlan
          ? 'server_plan'
          : 'server_subscription_status',
    });
  }

  return Object.freeze({
    tier: 'free',
    source:
      subscriptionStatus === 'trial'
        ? 'trial_not_authoritative_for_premium'
        : 'server_free_default',
  });
}

const formats = new Set(['visualSummary','fullSummary','examSummary','mindMap','flashcards','questionsAndAnswers','multipleChoice','oralExam','keyPoints','comparisonTable','finalPdf']);
function authorizeStudyArtifact(body, user, now = Date.now()) {
  const format = body.studyArtifactType ?? (body.studyArtifactFormat === 'study-visual-v1' ? 'visualSummary' : null);
  if (format == null) return null; // Existing chat and non-artifact requests unchanged.
  if (!formats.has(format)) return 'study_artifact_type_invalid';
  if (format === 'fullSummary' || format === 'keyPoints') return null;
  return resolveMedCasesTier(user, now).tier === 'premium' ? null : 'study_premium_required';
}
module.exports = {authorizeStudyArtifact};

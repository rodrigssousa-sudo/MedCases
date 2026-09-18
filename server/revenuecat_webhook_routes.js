'use strict';

const crypto = require('node:crypto');
const { getFirestore } = require('firebase-admin/firestore');

const WEBHOOK_PATH = '/api/billing/revenuecat/webhook';
const WEBHOOK_AUTH_ENV = 'MEDCASES_REVENUECAT_WEBHOOK_AUTH';
const PREMIUM_ENTITLEMENT = 'medcases_pro_premium';

function clean(value) { return String(value ?? '').trim(); }

function safeEqualText(left, right) {
  const a = Buffer.from(clean(left), 'utf8');
  const b = Buffer.from(clean(right), 'utf8');
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

function isAuthorizedWebhook(headerValue, expectedValue) {
  const expected = clean(expectedValue);
  if (Buffer.byteLength(expected, 'utf8') < 32) return false;
  return safeEqualText(headerValue, expected);
}

function deriveRevenueCatBillingState(event, nowMs = Date.now()) {
  if (!event || typeof event !== 'object') return { ignored: true, reason: 'event_missing' };

  const type = clean(event.type).toUpperCase();
  const uid = clean(event.app_user_id);
  const eventId = clean(event.id);
  const eventTimestampMs = Number(event.event_timestamp_ms);
  const entitlementIds = Array.isArray(event.entitlement_ids)
    ? event.entitlement_ids.map(clean)
    : [];

  if (!eventId || !Number.isFinite(eventTimestampMs)) {
    return { ignored: true, reason: 'event_identity_invalid' };
  }
  if (!uid || uid.startsWith('$RCAnonymousID:') || uid.length > 128) {
    return { ignored: true, reason: 'app_user_id_not_firebase_uid' };
  }
  if (!entitlementIds.includes(PREMIUM_ENTITLEMENT)) {
    return { ignored: true, reason: 'premium_entitlement_not_affected' };
  }

  const expiry = Number(event.expiration_at_ms);
  const grace = Number(event.grace_period_expiration_at_ms);
  const candidates = [expiry, grace].filter((v) => Number.isFinite(v) && v > 0);
  const effectiveExpiresAtMs = candidates.length ? Math.max(...candidates) : 0;
  const hardRevoke = type === 'EXPIRATION' || type === 'REFUND';
  const active = !hardRevoke && effectiveExpiresAtMs > Number(nowMs);

  return {
    ignored: false,
    uid,
    eventId,
    eventTimestampMs,
    type,
    active,
    effectiveExpiresAtMs,
    productId: clean(event.product_id),
    periodType: clean(event.period_type),
    environment: clean(event.environment),
    store: clean(event.store),
  };
}

function createRevenueCatWebhookHandler({
  db,
  authorizationProvider = () => process.env[WEBHOOK_AUTH_ENV],
  nowMsProvider = () => Date.now(),
} = {}) {
  if (!db || typeof db.collection !== 'function') {
    throw new Error('REVENUECAT_WEBHOOK_DB_REQUIRED');
  }

  return async function revenueCatWebhookHandler(req, res) {
    res.setHeader('Cache-Control', 'no-store');

    if (!isAuthorizedWebhook(req.headers?.authorization, authorizationProvider())) {
      return res.status(401).json({ ok: false, error: 'REVENUECAT_WEBHOOK_UNAUTHORIZED' });
    }

    const state = deriveRevenueCatBillingState(req.body?.event, nowMsProvider());
    if (state.ignored) {
      return res.status(200).json({ ok: true, ignored: true, reason: state.reason });
    }

    const userRef = db.collection('users').doc(state.uid);
    let snap;
    try { snap = await userRef.get(); }
    catch (_) { return res.status(503).json({ ok: false, error: 'REVENUECAT_USER_LOOKUP_FAILED' }); }

    if (!snap || snap.exists !== true) {
      return res.status(404).json({ ok: false, error: 'REVENUECAT_FIREBASE_USER_NOT_FOUND' });
    }

    const current = typeof snap.data === 'function' ? (snap.data() || {}) : {};
    const previousTs = Number(current.billingLastEventTimestampMs ?? 0);
    if (Number.isFinite(previousTs) && previousTs > state.eventTimestampMs) {
      return res.status(200).json({ ok: true, ignored: true, reason: 'stale_event' });
    }

    try {
      await userRef.set({
        billingEntitlementActive: state.active,
        billingEntitlementId: PREMIUM_ENTITLEMENT,
        billingEntitlementExpiresAtMs: state.effectiveExpiresAtMs,
        billingProvider: 'revenuecat',
        billingProductId: state.productId,
        billingPeriodType: state.periodType,
        billingStore: state.store,
        billingEnvironment: state.environment,
        billingLastEventType: state.type,
        billingLastEventId: state.eventId,
        billingLastEventTimestampMs: state.eventTimestampMs,
        billingUpdatedAtMs: nowMsProvider(),
      }, { merge: true });
    } catch (_) {
      return res.status(503).json({ ok: false, error: 'REVENUECAT_ENTITLEMENT_WRITE_FAILED' });
    }

    return res.status(200).json({ ok: true, uid: state.uid, active: state.active });
  };
}

function registerRevenueCatWebhookRoutes({ app, firebaseAdminApp, authorizationProvider, nowMsProvider } = {}) {
  if (!app || typeof app.post !== 'function') throw new Error('REVENUECAT_WEBHOOK_APP_REQUIRED');
  if (!firebaseAdminApp) throw new Error('REVENUECAT_WEBHOOK_FIREBASE_APP_REQUIRED');
  const db = getFirestore(firebaseAdminApp);
  app.post(WEBHOOK_PATH, createRevenueCatWebhookHandler({ db, authorizationProvider, nowMsProvider }));
  return Object.freeze({ path: WEBHOOK_PATH, method: 'POST' });
}

module.exports = {
  WEBHOOK_PATH,
  WEBHOOK_AUTH_ENV,
  PREMIUM_ENTITLEMENT,
  isAuthorizedWebhook,
  deriveRevenueCatBillingState,
  createRevenueCatWebhookHandler,
  registerRevenueCatWebhookRoutes,
};

'use strict';
const assert = require('node:assert/strict');
const {
  WEBHOOK_PATH,
  PREMIUM_ENTITLEMENT,
  isAuthorizedWebhook,
  deriveRevenueCatBillingState,
  createRevenueCatWebhookHandler,
} = require('../revenuecat_webhook_routes');

const AUTH = 'Bearer test-only-revenuecat-webhook-authorization-0123456789';
const NOW = 2_000_000_000_000;

function response() {
  return {
    statusCode: 200, headers: {}, body: null,
    setHeader(k, v) { this.headers[String(k).toLowerCase()] = String(v); },
    status(c) { this.statusCode = c; return this; },
    json(b) { this.body = b; return this; },
  };
}

function db(existing = {}) {
  const writes = [], records = new Map([['users/firebase-uid-123', existing]]);
  const orderId = require('node:crypto').createHash('sha256').update('firebase-uid-123').digest('hex');
  if (existing.billingLastEventTimestampMs) records.set('revenuecatBillingOrder/'+orderId,existing);
  return {
    writes, collection: name => ({doc: uid => `${name}/${uid}`}),
    async runTransaction(action) {
      return action({
        get: async ref => ({exists: records.has(ref), data: () => records.get(ref)}),
        set: (ref, payload, options) => {
          records.set(ref, {...records.get(ref), ...payload});
          if (ref.startsWith('users/')) writes.push({payload, options});
        },
      });
    },
  };
}

function event(type = 'INITIAL_PURCHASE', overrides = {}) {
  return {
    id: `evt-${type}`,
    type,
    app_user_id: 'firebase-uid-123',
    event_timestamp_ms: NOW,
    expiration_at_ms: NOW + 30 * 24 * 3600 * 1000,
    entitlement_ids: [PREMIUM_ENTITLEMENT],
    product_id: 'medcases_premium_monthly:monthly',
    period_type: 'TRIAL',
    environment: 'SANDBOX',
    store: 'PLAY_STORE',
    ...overrides,
  };
}

async function run() {
  assert.equal(WEBHOOK_PATH, '/api/billing/revenuecat/webhook');
  assert.equal(isAuthorizedWebhook(AUTH, AUTH), true);
  assert.equal(isAuthorizedWebhook('wrong', AUTH), false);

  assert.equal(deriveRevenueCatBillingState(event(), NOW).active, true);
  assert.equal(deriveRevenueCatBillingState(event('CANCELLATION'), NOW).active, true);
  assert.equal(deriveRevenueCatBillingState(event('EXPIRATION', { expiration_at_ms: NOW - 1 }), NOW).active, false);
  assert.equal(deriveRevenueCatBillingState(event('INITIAL_PURCHASE', { app_user_id: '$RCAnonymousID:bad' }), NOW).ignored, true);

  const fakeDb = db();
  const handler = createRevenueCatWebhookHandler({
    db: fakeDb,
    authorizationProvider: () => AUTH,
    nowMsProvider: () => NOW,
  });
  const unauth = response();
  await handler({ headers: { authorization: 'wrong' }, body: { event: event() } }, unauth);
  assert.equal(unauth.statusCode, 401);
  assert.equal(fakeDb.writes.length, 0);

  const ok = response();
  await handler({ headers: { authorization: AUTH }, body: { event: event() } }, ok);
  assert.equal(ok.statusCode, 200);
  assert.equal(fakeDb.writes.length, 1);
  assert.equal(fakeDb.writes[0].payload.billingEntitlementActive, true);

  const staleDb = db({ billingLastEventTimestampMs: NOW + 1 });
  const staleHandler = createRevenueCatWebhookHandler({
    db: staleDb,
    authorizationProvider: () => AUTH,
    nowMsProvider: () => NOW,
  });
  const stale = response();
  await staleHandler({ headers: { authorization: AUTH }, body: { event: event() } }, stale);
  assert.equal(stale.body.ignored, true);
  assert.equal(staleDb.writes.length, 0);

  console.log('REVENUECAT_WEBHOOK_AUTH=PASS');
  console.log('REVENUECAT_TRIAL_SERVER_GRANT=PASS');
  console.log('REVENUECAT_EXPIRATION_REVOKE=PASS');
  console.log('REVENUECAT_STALE_EVENT_BLOCKED=PASS');
}
run().catch((e) => { console.error(e); process.exit(1); });

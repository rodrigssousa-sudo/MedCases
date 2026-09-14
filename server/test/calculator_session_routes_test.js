'use strict';

const assert = require('node:assert/strict');

const {
  SESSION_PATH,
  parseBearerToken,
  createCalculatorSessionHandler,
} = require('../calculator_session_routes');

const SECRET =
  'test-only-medcases-calculator-session-secret-0123456789abcdef';
const NOW = 2_000_000_000;

function makeResponse() {
  return {
    statusCode: 200,
    headers: {},
    body: undefined,
    setHeader(name, value) {
      this.headers[String(name).toLowerCase()] = String(value);
    },
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };
}

function makeDb(userDoc, exists = true) {
  return {
    collection(name) {
      assert.equal(name, 'users');
      return {
        doc(uid) {
          assert.equal(uid, 'verified-uid');
          return {
            async get() {
              return {
                exists,
                data: () => userDoc,
              };
            },
          };
        },
      };
    },
  };
}

async function run() {
  assert.equal(SESSION_PATH, '/api/calculator/session');
  assert.equal(parseBearerToken('Bearer abc'), 'abc');
  assert.equal(parseBearerToken(''), '');

  const auth = {
    async verifyIdToken(token, checkRevoked) {
      assert.equal(token, 'valid-firebase-token');
      assert.equal(checkRevoked, true);
      return { uid: 'verified-uid' };
    },
  };

  const freeHandler = createCalculatorSessionHandler({
    auth,
    db: makeDb({
      plan: 'free',
      subscriptionStatus: 'trial',
    }),
    secretProvider: () => SECRET,
    nowEpochProvider: () => NOW,
  });

  const freeRes = makeResponse();
  await freeHandler(
    {
      headers: {
        authorization: 'Bearer valid-firebase-token',
      },
      body: {
        uid: 'attacker-controlled-uid',
        premium: true,
      },
      query: {
        premium: 'true',
      },
    },
    freeRes,
  );

  assert.equal(freeRes.statusCode, 200);
  assert.equal(freeRes.body.ok, true);
  assert.equal(freeRes.body.tier, 'free');
  assert.equal(
    freeRes.body.capabilities.includes('drug_catalog_full'),
    false,
  );
  assert.equal(
    freeRes.headers['cache-control'],
    'private, no-store',
  );

  const premiumHandler = createCalculatorSessionHandler({
    auth,
    db: makeDb({
      plan: 'premium',
      subscriptionStatus: 'active',
    }),
    secretProvider: () => SECRET,
    nowEpochProvider: () => NOW,
  });

  const premiumRes = makeResponse();
  await premiumHandler(
    {
      headers: {
        authorization: 'Bearer valid-firebase-token',
      },
      body: {},
      query: {},
    },
    premiumRes,
  );

  assert.equal(premiumRes.statusCode, 200);
  assert.equal(premiumRes.body.tier, 'premium');
  assert.equal(
    premiumRes.body.capabilities.includes('drug_catalog_full'),
    true,
  );
  assert.equal(
    premiumRes.body.capabilities.includes('dose_by_weight'),
    true,
  );
  assert.equal(
    premiumRes.body.capabilities.includes('renal_adjustment'),
    true,
  );

  const noTokenRes = makeResponse();
  await freeHandler(
    { headers: {}, body: {}, query: {} },
    noTokenRes,
  );
  assert.equal(noTokenRes.statusCode, 401);
  assert.equal(
    noTokenRes.body.error,
    'FIREBASE_ID_TOKEN_REQUIRED',
  );

  const missingUserHandler = createCalculatorSessionHandler({
    auth,
    db: makeDb({}, false),
    secretProvider: () => SECRET,
    nowEpochProvider: () => NOW,
  });

  const missingUserRes = makeResponse();
  await missingUserHandler(
    {
      headers: {
        authorization: 'Bearer valid-firebase-token',
      },
    },
    missingUserRes,
  );
  assert.equal(missingUserRes.statusCode, 403);
  assert.equal(missingUserRes.body.error, 'USER_NOT_FOUND');

  const noSecretHandler = createCalculatorSessionHandler({
    auth,
    db: makeDb({ plan: 'free' }),
    secretProvider: () => '',
    nowEpochProvider: () => NOW,
  });

  const noSecretRes = makeResponse();
  await noSecretHandler(
    {
      headers: {
        authorization: 'Bearer valid-firebase-token',
      },
    },
    noSecretRes,
  );
  assert.equal(noSecretRes.statusCode, 503);
  assert.equal(
    noSecretRes.body.error,
    'CALCULATOR_SESSION_SECRET_UNAVAILABLE',
  );

  console.log('APP_CALCULATOR_SESSION_ROUTE_TEST=PASS');
  console.log('FIREBASE_UID_SERVER_DERIVED=PASS');
  console.log('CLIENT_PREMIUM_FLAG_IGNORED=PASS');
  console.log('TRIAL_REMAINS_FREE=PASS');
  console.log('PREMIUM_CAPABILITIES_ISSUED=PASS');
  console.log('SESSION_NO_STORE_HEADER=PASS');
  console.log('MISSING_USER_DENIED=PASS');
  console.log('MISSING_SECRET_FAIL_CLOSED=PASS');
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});

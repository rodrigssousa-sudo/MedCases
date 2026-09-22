'use strict';
const { signOfflineEntitlement } = require('./offline_entitlement_lease');

const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
const {
  issueCalculatorSession,
} = require('./calculator_entitlement_session');

const SESSION_SECRET_ENV = 'MEDCASES_CALCULATOR_SESSION_SECRET';
const SESSION_PATH = '/api/calculator/session';

function parseBearerToken(headerValue) {
  const raw = String(headerValue || '').trim();
  const match = /^Bearer\s+(.+)$/i.exec(raw);
  return match ? match[1].trim() : '';
}

function jsonError(res, status, code) {
  return res.status(status).json({
    ok: false,
    error: code,
  });
}

function createCalculatorSessionHandler({
  auth,
  db,
  secretProvider = () => process.env[SESSION_SECRET_ENV],
  nowEpochProvider = () => Math.floor(Date.now() / 1000),
} = {}) {
  if (!auth || typeof auth.verifyIdToken !== 'function') {
    throw new Error('CALCULATOR_SESSION_ROUTE_AUTH_REQUIRED');
  }

  if (!db || typeof db.collection !== 'function') {
    throw new Error('CALCULATOR_SESSION_ROUTE_DB_REQUIRED');
  }

  return async function calculatorSessionHandler(req, res) {
    res.setHeader('Cache-Control', 'private, no-store');
    res.setHeader('Pragma', 'no-cache');

    const idToken = parseBearerToken(req.headers?.authorization);

    if (!idToken) {
      return jsonError(res, 401, 'FIREBASE_ID_TOKEN_REQUIRED');
    }

    let decoded;
    try {
      decoded = await auth.verifyIdToken(idToken, true);
    } catch (_) {
      return jsonError(res, 401, 'FIREBASE_ID_TOKEN_INVALID');
    }

    const uid = String(decoded?.uid || '').trim();
    if (!uid) {
      return jsonError(res, 401, 'FIREBASE_UID_MISSING');
    }

    let userSnap;
    try {
      userSnap = await db.collection('users').doc(uid).get();
    } catch (_) {
      return jsonError(res, 503, 'USER_ENTITLEMENT_LOOKUP_FAILED');
    }

    if (!userSnap || userSnap.exists !== true) {
      return jsonError(res, 403, 'USER_NOT_FOUND');
    }

    const secret = String(secretProvider() || '').trim();
    if (Buffer.byteLength(secret, 'utf8') < 32) {
      return jsonError(res, 503, 'CALCULATOR_SESSION_SECRET_UNAVAILABLE');
    }

    const userDoc =
      typeof userSnap.data === 'function'
        ? (userSnap.data() || {})
        : {};

    let issued;
    let offlineEntitlement;
    try {
      issued = issueCalculatorSession({
        uid,
        userDoc,
        secret,
        nowEpoch: nowEpochProvider(),
      });
      offlineEntitlement = signOfflineEntitlement({
        ...issued.claims,
        // The offline lease is independent from the short-lived MCC1 session.
        // Only the authoritative billing record can extend its upper bound.
        exp: issued.entitlementSource === 'server_revenuecat_entitlement'
          ? Math.floor(Number(userDoc.billingEntitlementExpiresAtMs) / 1000)
          : issued.claims.exp,
      });
    } catch (_) {
      return jsonError(res, 503, 'CALCULATOR_SESSION_ISSUE_FAILED');
    }

    return res.status(200).json({
      ok: true,
      offlineEntitlement,
      accessToken: issued.accessToken,
      tier: issued.claims.tier,
      capabilities: issued.claims.cap,
      expiresAtUtc: issued.expiresAtUtc,
      entitlementSource: issued.entitlementSource,
    });
  };
}

function registerCalculatorSessionRoutes({
  app,
  firebaseAdminApp,
  secretProvider,
  nowEpochProvider,
} = {}) {
  if (!app || typeof app.post !== 'function') {
    throw new Error('CALCULATOR_SESSION_ROUTE_APP_REQUIRED');
  }

  if (!firebaseAdminApp) {
    throw new Error('CALCULATOR_SESSION_ROUTE_FIREBASE_APP_REQUIRED');
  }

  const auth = getAuth(firebaseAdminApp);
  const db = getFirestore(firebaseAdminApp);

  const handler = createCalculatorSessionHandler({
    auth,
    db,
    secretProvider,
    nowEpochProvider,
  });

  app.post(SESSION_PATH, handler);

  return Object.freeze({
    path: SESSION_PATH,
    method: 'POST',
    cacheControl: 'private, no-store',
  });
}

module.exports = {
  SESSION_SECRET_ENV,
  SESSION_PATH,
  parseBearerToken,
  createCalculatorSessionHandler,
  registerCalculatorSessionRoutes,
};

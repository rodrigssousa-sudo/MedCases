'use strict';

const VERSION =
  'medcases_study_google_ai_oauth_token_exchange_secret_bound_v1';

const TOKEN_ENDPOINT =
  'https://oauth2.googleapis.com/token';

const CLIENT_SECRET_ENV =
  'MEDCASES_STUDY_GOOGLE_OAUTH_WEB_CLIENT_SECRET_V1';

function cleanString(value) {
  return typeof value === 'string'
    ? value.trim()
    : '';
}

function readBoundClientSecret(env = process.env) {
  const value = cleanString(
    env && env[CLIENT_SECRET_ENV]
  );

  if (value.length < 8) {
    throw new Error(
      'OAUTH_CLIENT_SECRET_BOUND_ENV_MISSING'
    );
  }

  return value;
}

function assertPublicClientId(clientId) {
  const value = cleanString(clientId);

  if (
    !value ||
    !value.endsWith(
      '.apps.googleusercontent.com'
    )
  ) {
    throw new Error(
      'OAUTH_WEB_CLIENT_ID_INVALID'
    );
  }

  return value;
}

function assertAuthorizationCode(code) {
  const value = cleanString(code);

  if (!value) {
    throw new Error(
      'SERVER_AUTHORIZATION_CODE_MISSING'
    );
  }

  return value;
}

function resolveFetch(fetchImpl) {
  if (typeof fetchImpl === 'function') {
    return fetchImpl;
  }

  if (typeof globalThis.fetch === 'function') {
    return globalThis.fetch.bind(globalThis);
  }

  throw new Error(
    'FETCH_IMPLEMENTATION_UNAVAILABLE'
  );
}

function safeTokenResponse(data) {
  const source =
    data && typeof data === 'object'
      ? data
      : {};

  const accessToken =
    cleanString(source.access_token);

  if (!accessToken) {
    throw new Error(
      'OAUTH_ACCESS_TOKEN_MISSING'
    );
  }

  return {
    accessToken,
    refreshToken:
      cleanString(source.refresh_token) || null,
    idToken:
      cleanString(source.id_token) || null,
    tokenType:
      cleanString(source.token_type) || null,
    scope:
      cleanString(source.scope) || null,
    expiresInSeconds:
      Number.isFinite(
        Number(source.expires_in)
      )
        ? Number(source.expires_in)
        : null,
  };
}

async function exchangeServerAuthorizationCode({
  serverAuthorizationCode,
  clientId,
  clientSecret,
  redirectUri = '',
  fetchImpl,
}) {
  const code =
    assertAuthorizationCode(
      serverAuthorizationCode
    );

  const publicClientId =
    assertPublicClientId(clientId);

  const secret =
    cleanString(clientSecret);

  if (secret.length < 8) {
    throw new Error(
      'OAUTH_CLIENT_SECRET_MISSING'
    );
  }

  const requestFetch =
    resolveFetch(fetchImpl);

  const body =
    new URLSearchParams({
      code,
      client_id: publicClientId,
      client_secret: secret,
      grant_type: 'authorization_code',
      redirect_uri:
        typeof redirectUri === 'string'
          ? redirectUri
          : '',
    });

  const response =
    await requestFetch(
      TOKEN_ENDPOINT,
      {
        method: 'POST',
        headers: {
          'Content-Type':
            'application/x-www-form-urlencoded',
          Accept: 'application/json',
        },
        body: body.toString(),
      }
    );

  let data = {};

  try {
    data = await response.json();
  } catch (_) {
    data = {};
  }

  if (!response.ok) {
    const safeError =
      cleanString(data.error) ||
      'oauth_exchange_failed';

    const error = new Error(
      'OAUTH_TOKEN_EXCHANGE_FAILED'
    );

    error.safeOAuthError = safeError;
    error.httpStatus =
      Number(response.status) || 0;

    throw error;
  }

  return safeTokenResponse(data);
}

async function exchangeWithBoundSecret({
  serverAuthorizationCode,
  clientId,
  redirectUri = '',
  fetchImpl,
  env = process.env,
}) {
  const clientSecret =
    readBoundClientSecret(env);

  return exchangeServerAuthorizationCode({
    serverAuthorizationCode,
    clientId,
    clientSecret,
    redirectUri,
    fetchImpl,
  });
}

module.exports = {
  VERSION,
  TOKEN_ENDPOINT,
  CLIENT_SECRET_ENV,
  readBoundClientSecret,
  exchangeServerAuthorizationCode,
  exchangeWithBoundSecret,
};

'use strict';

const DEFAULT_TOKEN_ENDPOINT = 'https://oauth2.googleapis.com/token';

function requireNonEmptyString(value, name) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new TypeError(`${name}_REQUIRED`);
  }
  return value.trim();
}

function createRefreshAccessTokenV1({
  fetchImpl,
  clientId,
  clientSecret,
  tokenEndpoint = DEFAULT_TOKEN_ENDPOINT,
}) {
  if (typeof fetchImpl !== 'function') {
    throw new TypeError('FETCH_IMPL_REQUIRED');
  }
  const oauthClientId = requireNonEmptyString(clientId, 'CLIENT_ID');
  const oauthClientSecret = requireNonEmptyString(
    clientSecret,
    'CLIENT_SECRET',
  );
  const endpoint = requireNonEmptyString(tokenEndpoint, 'TOKEN_ENDPOINT');

  return async function refreshAccessToken({ refreshToken }) {
    const token = requireNonEmptyString(refreshToken, 'REFRESH_TOKEN');

    const body = new URLSearchParams();
    body.set('client_id', oauthClientId);
    body.set('client_secret', oauthClientSecret);
    body.set('refresh_token', token);
    body.set('grant_type', 'refresh_token');

    const response = await fetchImpl(endpoint, {
      method: 'POST',
      headers: {
        'content-type': 'application/x-www-form-urlencoded',
      },
      body: body.toString(),
    });

    if (!response || typeof response.json !== 'function') {
      throw new Error('OAUTH_REFRESH_INVALID_RESPONSE');
    }

    const payload = await response.json();
    if (!response.ok) {
      const safeError =
        payload && typeof payload.error === 'string'
          ? payload.error
          : 'unknown';
      throw new Error(`OAUTH_REFRESH_FAILED:${safeError}`);
    }

    const accessToken =
      payload && typeof payload.access_token === 'string'
        ? payload.access_token.trim()
        : '';

    if (!accessToken) {
      throw new Error('OAUTH_REFRESH_ACCESS_TOKEN_MISSING');
    }

    return Object.freeze({
      accessToken,
      scope:
        payload && typeof payload.scope === 'string'
          ? payload.scope.trim()
          : '',
      expiresIn:
        payload && Number.isFinite(Number(payload.expires_in))
          ? Number(payload.expires_in)
          : null,
    });
  };
}

module.exports = {
  DEFAULT_TOKEN_ENDPOINT,
  createRefreshAccessTokenV1,
};

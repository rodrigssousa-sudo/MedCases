'use strict';

const assert = require('assert');

const {
  VERSION,
  SCHEMA_VERSION,
  buildEncryptedGrantRecord,
  assertRecordContainsNoPlaintext,
  persistEncryptedOAuthGrant,
} = require(
  '../lib/ai_control_plane_v2/' +
  'study_google_ai_oauth_refresh_token_project_vault_v1'
);

async function run() {
  assert.strictEqual(
    VERSION,
    'medcases_study_google_ai_oauth_refresh_token_project_vault_v1'
  );

  assert.strictEqual(
    SCHEMA_VERSION,
    1
  );

  const fakeRefreshToken =
    'fake-refresh-token-test-only';

  const fakeAccessToken =
    'fake-access-token-test-only';

  let encryptCalls = 0;
  let storeCalls = 0;
  let stored = null;

  const encryptRefreshToken =
    async ({ plaintext, aad }) => {
      encryptCalls += 1;

      assert.strictEqual(
        plaintext,
        fakeRefreshToken
      );

      const aadObject =
        JSON.parse(aad);

      assert.strictEqual(
        aadObject.medCasesUid,
        'uid-test-1'
      );

      assert.strictEqual(
        aadObject.validatedUserProjectId,
        'user-project-12345'
      );

      return (
        'kms-ciphertext-test-only:' +
        Buffer.from(
          plaintext,
          'utf8'
        ).toString('base64')
      );
    };

  const storeEncryptedGrant =
    async ({ medCasesUid, record }) => {
      storeCalls += 1;

      assert.strictEqual(
        medCasesUid,
        'uid-test-1'
      );

      stored = JSON.parse(
        JSON.stringify(record)
      );
    };

  const result =
    await persistEncryptedOAuthGrant({
      medCasesUid:
        'uid-test-1',
      validatedUserProjectId:
        'user-project-12345',
      refreshToken:
        fakeRefreshToken,
      accessToken:
        fakeAccessToken,
      grantedScopes: [
        'scope-b',
        'scope-a',
        'scope-a',
      ],
      encryptRefreshToken,
      storeEncryptedGrant,
      now:
        new Date(
          '2026-08-29T15:30:00.000Z'
        ),
    });

  assert.strictEqual(
    encryptCalls,
    1
  );

  assert.strictEqual(
    storeCalls,
    1
  );

  assert.ok(stored);

  assert.strictEqual(
    stored.medCasesUid,
    'uid-test-1'
  );

  assert.strictEqual(
    stored.validatedUserProjectId,
    'user-project-12345'
  );

  assert.strictEqual(
    stored.projectSource,
    'server_validated'
  );

  assert.strictEqual(
    stored.accessTokenPersisted,
    false
  );

  assert.strictEqual(
    stored.refreshTokenPlaintextPersisted,
    false
  );

  assert.deepStrictEqual(
    stored.grantedScopes,
    [
      'scope-a',
      'scope-b',
    ]
  );

  const serialized =
    JSON.stringify(stored);

  assert.strictEqual(
    serialized.includes(
      fakeRefreshToken
    ),
    false
  );

  assert.strictEqual(
    serialized.includes(
      fakeAccessToken
    ),
    false
  );

  assert.strictEqual(
    result.persisted,
    true
  );

  assert.strictEqual(
    result.refreshTokenPlaintextPersisted,
    false
  );

  assert.strictEqual(
    result.accessTokenPersisted,
    false
  );

  const standalone =
    await buildEncryptedGrantRecord({
      medCasesUid:
        'uid-test-2',
      validatedUserProjectId:
        'another-project-123',
      refreshToken:
        'another-fake-refresh-token',
      encryptRefreshToken:
        async () =>
          'another-kms-ciphertext',
      now:
        new Date(
          '2026-08-29T15:31:00.000Z'
        ),
    });

  assert.strictEqual(
    assertRecordContainsNoPlaintext({
      record:
        standalone,
      refreshToken:
        'another-fake-refresh-token',
      accessToken:
        'another-fake-access-token',
    }),
    true
  );

  await assert.rejects(
    () =>
      buildEncryptedGrantRecord({
        medCasesUid:
          'uid-test-3',
        validatedUserProjectId:
          'project-12345',
        refreshToken:
          'plaintext-token-test',
        encryptRefreshToken:
          async ({ plaintext }) =>
            plaintext,
      }),
    /ENCRYPTOR_RETURNED_PLAINTEXT/
  );

  await assert.rejects(
    () =>
      buildEncryptedGrantRecord({
        medCasesUid:
          'uid-test-4',
        validatedUserProjectId:
          'INVALID PROJECT',
        refreshToken:
          'plaintext-token-test',
        encryptRefreshToken:
          async () =>
            'ciphertext-test-only',
      }),
    /VALIDATED_GOOGLE_PROJECT_ID_INVALID/
  );

  console.log(
    'VAULT_UID_BINDING_CONTRACT=PASS'
  );

  console.log(
    'VAULT_SERVER_VALIDATED_PROJECT_BINDING_CONTRACT=PASS'
  );

  console.log(
    'VAULT_REFRESH_TOKEN_ENCRYPTION_REQUIRED=PASS'
  );

  console.log(
    'VAULT_PLAINTEXT_REFRESH_TOKEN_PERSISTENCE_ZERO=PASS'
  );

  console.log(
    'VAULT_ACCESS_TOKEN_PERSISTENCE_ZERO=PASS'
  );

  console.log(
    'VAULT_PLAINTEXT_ENCRYPTOR_REJECTED=PASS'
  );

  console.log(
    'REAL_KMS_CALLS=0'
  );

  console.log(
    'REAL_FIRESTORE_WRITES=0'
  );

  console.log(
    'RESULT=PASS_STUDY_GOOGLE_AI_OAUTH_REFRESH_TOKEN_PROJECT_VAULT_CONTRACT'
  );
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});

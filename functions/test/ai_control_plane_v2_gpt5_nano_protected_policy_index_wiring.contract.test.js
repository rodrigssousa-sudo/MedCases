'use strict';

const fs=require('fs');
const path=require('path');
const assert=require('assert');

const indexPath=path.join(__dirname,'..','index.js');
const source=fs.readFileSync(indexPath,'utf8');

assert.ok(
  source.includes(
    "buildOpenAiProtectedClinicalDataPolicyFromEnv"
  )
);

assert.ok(
  source.includes(
    "buildOpenAiProtectedClinicalDataPolicyFromEnv(\n          process.env\n        )"
  )
);

assert.ok(
  source.includes(
    "protectedClinicalProjection: __protectedClinicalProjectionV2"
  )
);

assert.strictEqual(
  /providerDataPolicy\s*:\s*req\.body/.test(source),
  false
);

assert.strictEqual(
  /protectedClinicalProjection\s*:\s*req\.body/.test(source),
  false
);

console.log('INDEX_PROVIDER_POLICY_SOURCE=SERVER_ENV_ONLY');
console.log('INDEX_CLIENT_PROVIDER_POLICY_ACCEPTED=NO');
console.log('INDEX_CLIENT_PROTECTED_PROJECTION_ACCEPTED=NO');
console.log('INDEX_PROTECTED_CLINICAL_POLICY_WIRING=PASS');

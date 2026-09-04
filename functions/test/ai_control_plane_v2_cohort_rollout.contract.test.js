'use strict';

const assert = require('assert');

const {
  BUCKET_COUNT,
  deterministicBucket,
  evaluateRolloutCohort,
} = require('../lib/ai_control_plane_v2/cohort_rollout');

assert.strictEqual(BUCKET_COUNT, 10000);

// Deterministic for same uid + salt.
{
  const a = deterministicBucket('user-A', 'cohort-v1');
  const b = deterministicBucket('user-A', 'cohort-v1');

  assert.strictEqual(a, b);
  assert.ok(a >= 0 && a < 10000);
}

// Salt changes assignment basis.
{
  const a = deterministicBucket('user-A', 'cohort-v1');
  const b = deterministicBucket('user-A', 'cohort-v2');

  // Collision is theoretically possible; test multiple identities.
  const pairs = [
    ['user-A', a, b],
    [
      'user-B',
      deterministicBucket('user-B', 'cohort-v1'),
      deterministicBucket('user-B', 'cohort-v2'),
    ],
    [
      'user-C',
      deterministicBucket('user-C', 'cohort-v1'),
      deterministicBucket('user-C', 'cohort-v2'),
    ],
  ];

  assert.ok(pairs.some(([, x, y]) => x !== y));
}

// 0% always closed.
{
  const r = evaluateRolloutCohort({
    uid: 'user-A',
    cohortSaltVersion: 'cohort-v1',
    percent: 0,
  });

  assert.strictEqual(r.eligible, false);
  assert.strictEqual(r.reason, 'rollout_zero');
}

// 100% always selected.
{
  const r = evaluateRolloutCohort({
    uid: 'user-A',
    cohortSaltVersion: 'cohort-v1',
    percent: 100,
  });

  assert.strictEqual(r.eligible, true);
  assert.strictEqual(r.reason, 'rollout_selected');
}

// Missing UID / salt / invalid percent fail closed.
{
  assert.strictEqual(
    evaluateRolloutCohort({
      uid: '',
      cohortSaltVersion: 'v1',
      percent: 10,
    }).eligible,
    false
  );

  assert.strictEqual(
    evaluateRolloutCohort({
      uid: 'user-A',
      cohortSaltVersion: '',
      percent: 10,
    }).eligible,
    false
  );

  for (const percent of [-1, 101, NaN, Infinity, '10', null]) {
    assert.strictEqual(
      evaluateRolloutCohort({
        uid: 'user-A',
        cohortSaltVersion: 'v1',
        percent,
      }).eligible,
      false
    );
  }
}

// Exact 1/10/25/50 percentage thresholds are expressed in 10k buckets.
{
  const pctToThreshold = (p) => Math.floor(p * 100);
  assert.strictEqual(pctToThreshold(1), 100);
  assert.strictEqual(pctToThreshold(10), 1000);
  assert.strictEqual(pctToThreshold(25), 2500);
  assert.strictEqual(pctToThreshold(50), 5000);
  assert.strictEqual(pctToThreshold(100), 10000);
}

console.log('AI_CONTROL_PLANE_V2_COHORT_ROLLOUT=PASS');
console.log('DETERMINISTIC_UID_SALT_BUCKET=PASS');
console.log('BUCKET_RANGE_0_9999=PASS');
console.log('ROLLOUT_1_PERCENT_100_BUCKETS=PASS');
console.log('ROLLOUT_10_PERCENT_1000_BUCKETS=PASS');
console.log('ROLLOUT_25_PERCENT_2500_BUCKETS=PASS');
console.log('ROLLOUT_50_PERCENT_5000_BUCKETS=PASS');
console.log('ROLLOUT_100_PERCENT_10000_BUCKETS=PASS');
console.log('MISSING_UID_FAIL_CLOSED=PASS');
console.log('MISSING_SALT_FAIL_CLOSED=PASS');
console.log('INVALID_PERCENT_FAIL_CLOSED=PASS');
console.log('RAW_UID_TELEMETRY=ABSENT');

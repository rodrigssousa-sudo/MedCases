'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

test('Study background route is durable, transient-audio and idempotent-capable', () => {
  const source = fs.readFileSync(
    'server/study_background_transcription_routes.js',
    'utf8',
  );

  for (const marker of [
    "getFirestore",
    "GRANT_SCOPE = 'study-background-transcription-v1'",
    "MAX_SEGMENTS = 64",
    "MAX_AUDIO_BYTES = 25 * 1024 * 1024",
    "MODEL = 'gpt-transcribe'",
    "audioPersistence: false",
    "transcriptCheckpoint: 'firestore-transient'",
    "express.raw",
    "state: 'processing'",
    "state: 'done'",
    "leaseUntil",
    "body.fill(0)",
    "cleanupExpiredJobs",
  ]) {
    assert.ok(source.includes(marker), marker);
  }
});

test('Study routes mount before global Firebase auth comment', () => {
  const source = fs.readFileSync('server/server.js', 'utf8');
  const registration = source.indexOf(
    'registerStudyBackgroundTranscriptionRoutes(app);',
  );
  const authBoundary = source.indexOf('// antes do Firebase global:');

  assert.ok(registration >= 0);
  assert.ok(authBoundary >= 0);
  assert.ok(registration < authBoundary);
});

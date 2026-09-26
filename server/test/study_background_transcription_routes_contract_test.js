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
    "audioPersistence: Boolean(queue())",
    "durable-queue-202",
    "transcriptCheckpoint: 'firestore-transient'",
    "express.raw",
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

// The owner-approved contract supersedes zero server persistence: dedicated
// encrypted temporary objects, authenticated access, durable result then cleanup.
test('durable private audio retains the privacy and deletion boundary',()=>{
 const storage=fs.readFileSync('server/transcription_temp_storage.js','utf8');
 assert.match(storage,/ServerSideEncryption: 'AES256'/);
 assert.match(storage,/TRANSCRIPTION_BUCKET_MUST_BE_DEDICATED/);
 assert.match(storage,/TRANSCRIPTION_ENDPOINT_REQUIRES_TLS/);
 assert.match(storage,/TRANSCRIPTION_OBJECT_BINDING_INVALID/);
 assert.doesNotMatch(storage,/ACL\s*:\s*['"]public/);
 const queue=fs.readFileSync('server/logical_recording_queue.js','utf8');
 assert.match(queue,/leaseUntil/);assert.match(queue,/deleted:true/);assert.match(queue,/LOGICAL_RECORDING_CANCELLED/);
 assert.match(queue,/storage.remove/);assert.match(queue,/providerDeleted/);
});

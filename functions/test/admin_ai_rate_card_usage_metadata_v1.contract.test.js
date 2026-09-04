'use strict';

const fs = require('fs');
const assert = require('assert');

const source = fs.readFileSync('functions/index.js', 'utf8');

for (const token of [
  'ADMIN_AI_OFFICIAL_RATE_CARD_V1',
  "'gpt-5.6':",
  "'gpt-5.6-sol':",
  "'gpt-4o-mini':",
  "'geminiPaidProxy:gemini-2.5-flash':",
  'inputPerMillionUsd: 4.00',
  'outputPerMillionUsd: 20.00',
  'inputPerMillionUsd: 0.15',
  'outputPerMillionUsd: 0.60',
  'inputPerMillionUsd: 0.30',
  'outputPerMillionUsd: 2.50',
  'longContextThresholdInputTokens: 272000',
  'longContextInputMultiplier: 2.0',
  'longContextOutputMultiplier: 1.5',
  'promptTokenCount',
  'candidatesTokenCount',
  'thoughtsTokenCount',
  'cachedContentTokenCount',
  'cachedInputTokens',
  'official_defaults_plus_firestore_override',
  'costRateVerifiedAt',
]) {
  assert.ok(source.includes(token), `missing token: ${token}`);
}

const marker = source.indexOf('ADMIN_AI_TELEMETRY_PRODUCER_V1');
const eventStart = source.indexOf('const event = {', marker);
const eventEnd = source.indexOf('};', eventStart);
assert.ok(marker >= 0 && eventStart > marker && eventEnd > eventStart);

const eventBlock = source.slice(eventStart, eventEnd + 2);

for (const forbidden of [
  'systemPrompt',
  'userMessage',
  'responseText',
  'history',
  'uid:',
  'email:',
  'apiKey',
  'secret:',
]) {
  assert.ok(
    !eventBlock.includes(forbidden),
    `privacy regression: ${forbidden}`,
  );
}

assert.ok(
  eventBlock.includes('cachedInputTokens:'),
  'cached input not persisted',
);

console.log('ADMIN_AI_RATE_CARD_USAGE_METADATA_V1_CONTRACT=PASS');

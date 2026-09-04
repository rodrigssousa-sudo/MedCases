'use strict';
const fs = require('fs');
const assert = require('assert');
const functions = fs.readFileSync('functions/index.js', 'utf8');
const rules = fs.readFileSync('firestore.rules', 'utf8');

for (const required of [
  'ADMIN_AI_TELEMETRY_PRODUCER_V1',
  "provider: 'openai'",
  "provider: 'gemini'",
  'inputTokens24h',
  'outputTokens24h',
  'totalTokens24h',
  'errors24h',
  'avgLatencyMs',
  'costTodayUsd',
  'estimatedMonthCostUsd',
  "window: 'rolling_24h'",
  "ADMIN_AI_RATE_CONFIG_PATH = 'app_config/ai_cost_rates'",
  "schedule: 'every 5 minutes'",
  'ADMIN_AI_USAGE_RETENTION_DAYS = 35',
]) assert.ok(functions.includes(required), `missing: ${required}`);

assert.ok(rules.includes('match /admin_ai_usage_events/{document=**}'));

const marker = functions.indexOf('ADMIN_AI_TELEMETRY_PRODUCER_V1');
const eventStart = functions.indexOf('const event = {', marker);
const eventEnd = functions.indexOf('};', eventStart);
assert.ok(marker > 0 && eventStart > marker && eventEnd > eventStart);
const eventBlock = functions.slice(eventStart, eventEnd + 2);

for (const forbidden of [
  'userMessage', 'systemPrompt', 'history', 'responseText', 'prompt:',
  'uid:', 'email:', 'apiKey', 'secret',
]) assert.ok(!eventBlock.includes(forbidden), `forbidden telemetry field: ${forbidden}`);

for (const required of [
  'provider:', 'model:', 'endpoint:', 'success:', 'inputTokens:',
  'outputTokens:', 'totalTokens:', 'durationMs:', 'errorCode:',
  'createdAt:', 'expiresAt:',
]) assert.ok(eventBlock.includes(required), `missing telemetry field: ${required}`);

console.log('ADMIN_AI_TELEMETRY_V1_CONTRACT=PASS');

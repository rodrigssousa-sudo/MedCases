'use strict';
// No free-form text accepted by this sink. Level is selected by code, not input.
const sink = globalThis.console;
const redacted = Object.fromEntries(
 ['log','info','warn','error','debug'].map(level => [level, (..._untrusted) =>
   sink[level]('MEDCASES_' + level.toUpperCase() + '_EVENT_REDACTED')]));

// Proposed H29A diagnostic only: no prompts, tokens, UID or free-form errors.
const reasons = new Set(['INVALID_ARGUMENT','FAILED_PRECONDITION','PERMISSION_DENIED',
 'UNAUTHENTICATED','RESOURCE_EXHAUSTED','NOT_FOUND','INTERNAL','UNAVAILABLE',
 'DEADLINE_EXCEEDED','BILLING_DISABLED','API_KEY_INVALID','SERVICE_DISABLED',
 'CONSUMER_INVALID','RATE_LIMIT_EXCEEDED','QUOTA_EXCEEDED']);
module.exports = Object.freeze({...redacted, providerFailure(status, reason, id) {
 if (!Number.isInteger(status) || status < 400 || status > 599 ||
     !/^[a-f0-9-]{36}$/.test(id)) return;
 sink.warn(JSON.stringify({event:'PROVIDER_HTTP_REJECTED', origin:'upstream',
   httpStatus:status, reason:reasons.has(reason)?reason:'UNCLASSIFIED', diagnosticId:id}));
}});

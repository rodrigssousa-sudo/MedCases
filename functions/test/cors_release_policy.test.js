'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {loadFunctions} = require('../../server/test/cors_policy_harness');
const loopbacks = ['http://localhost','http://localhost:3000','http://localhost:43210','http://127.0.0.1','http://127.0.0.1:43210'];
for (const env of [undefined, '', 'production', 'test', 'staging']) {
  test(`Functions emits no loopback CORS authorization in ${String(env)}`, () => {
    const accepts = loadFunctions(env);
    for (const origin of loopbacks) assert.equal(accepts(origin), false, origin);
    assert.equal(accepts('https://medcasespro.com'), true);
    assert.equal(accepts('https://www.medcasespro.com'), true);
  });
}
for (const env of ['development','local']) {
  test(`Functions explicit ${env} retains existing any-port local contract`, () => {
    const accepts = loadFunctions(env);
    for (const origin of loopbacks) assert.equal(accepts(origin), true, origin);
    assert.equal(accepts('https://medcasespro.com'), true);
  });
}
test('Functions never expands to wildcard lookalikes or unknown domains', () => {
  for (const env of ['production','development']) {
    const accepts = loadFunctions(env);
    for (const origin of ['http://localhost.attacker.invalid','http://127.0.0.1.attacker.invalid','https://untrusted.invalid','null']) assert.equal(accepts(origin), false);
  }
});

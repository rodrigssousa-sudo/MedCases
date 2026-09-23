'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {loadServer} = require('./cors_policy_harness');
const loopbacks = ['http://localhost','http://localhost:3000','http://localhost:43210','http://127.0.0.1','http://127.0.0.1:43210'];
for (const env of [undefined, '', 'production', 'test', 'staging']) {
  test(`server denies every loopback in ${String(env)}`, () => {
    const accepts = loadServer(env);
    for (const origin of loopbacks) assert.equal(accepts(origin), false, origin);
    assert.equal(accepts('https://medcasespro.com'), true);
    assert.equal(accepts(undefined), true, 'native no-Origin behavior preserved');
  });
}
for (const env of ['development', 'local']) {
  test(`server explicit ${env} preserves exact old local allowlist`, () => {
    const accepts = loadServer(env);
    for (const origin of ['http://localhost','http://localhost:3000','http://localhost:8080','http://127.0.0.1']) assert.equal(accepts(origin), true, origin);
    assert.equal(accepts('http://localhost:43210'), false);
    assert.equal(accepts('https://localhost'), false);
    assert.equal(accepts('https://medcasespro.com'), true);
  });
}
test('server production cannot allow loopback through ALLOWED_ORIGIN misconfiguration', () => {
  for (const origin of loopbacks) assert.equal(loadServer('production', origin)(origin), false);
});
test('server never expands to wildcard lookalikes or unknown domains', () => {
  for (const env of ['production','development']) {
    const accepts = loadServer(env);
    for (const origin of ['http://localhost.attacker.invalid','http://127.0.0.1.attacker.invalid','https://untrusted.invalid','null']) assert.equal(accepts(origin), false);
  }
});

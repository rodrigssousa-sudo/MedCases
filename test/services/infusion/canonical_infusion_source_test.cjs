'use strict';
// Runs the original calculator, not a transcription of its formulas.
// All numeric operands below are dimensionless test examples, not dosing advice.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');

if (!process.argv[2]) throw Error('Supply the read-only canonical repository path');
const root = path.resolve(process.argv[2]);
const fixture = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../../fixtures/infusion_binding_source/presets.json')));
const source = fs.readFileSync(path.join(root, fixture.source.infusionPath), 'utf8');
assert.equal(crypto.createHash('sha256').update(source).digest('hex'), fixture.source.infusionHash, 'Source changed: re-audit before running');
const context = {window: {}, document: {addEventListener() {}}};
vm.createContext(context);
vm.runInContext(source, context);
const actual = JSON.parse(vm.runInContext('JSON.stringify({fallback:INFUSION_FALLBACK_DB,presets:BIC_PRESETS})', context));
const math = context.window.InfusionMath;
const canonical = JSON.parse(fs.readFileSync(path.join(root, 'data/drugs_index.json')));
const ids = new Set(canonical.map(x => x.id));
for (const [file, expected] of Object.entries(fixture.source.additionalSourceHashes)) {
  assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(root, file))).digest('hex'), expected);
}
// Evaluate the existing name normalizer verbatim. Its interaction aliases
// include class groupings and therefore do not prove formulation identity.
vm.runInContext(fs.readFileSync(path.join(root, 'database/interacoes.js'), 'utf8'), context);
const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const start = html.indexOf('  function normalizarFarmaco(nome) {');
const end = html.indexOf('  window.normalizarFarmaco = normalizarFarmaco;', start);
assert.ok(start >= 0 && end > start);
vm.runInContext(html.slice(start, end), context);

test('canonical source inventory and fixture count agree', () => {
  assert.equal(canonical.length, fixture.source.canonicalCount);
  assert.equal(ids.size, canonical.length);
  assert.equal(fixture.bindings.length, actual.fallback.length);
  assert.equal(actual.fallback.length, 16);
});
for (const row of fixture.bindings) {
  test(`${row.bindingId}: exact source parity; no canonical identity assertion`, () => {
    const found = actual.fallback.find(x => x.nome === row.fallback.nome);
    assert.deepEqual(found, row.fallback);
    assert.deepEqual(actual.presets[found.nome], row.preparations);
    assert.equal(found.canonicalDrugId, undefined);
    assert.equal(found.drugId, undefined);
    assert.equal(found.id, undefined);
    assert.equal(ids.has(found.nome), false);
    assert.equal(ids.has(row.bindingId), false);
    for (const prep of row.preparations) assert.equal(prep.canonicalDrugId, undefined);
    const normalized = vm.runInContext(`normalizarFarmaco(${JSON.stringify(found.nome)})`, context);
    assert.equal(normalized, row.recognizedNormalization.normalized);
    assert.equal(ids.has(normalized), row.recognizedNormalization.canonicalExists);
    if (row.recognizedNormalization.canonicalExists) {
      const raw = fs.readFileSync(path.join(root, 'data/drugs', `${normalized}.json`));
      assert.equal(crypto.createHash('sha256').update(raw).digest('hex'), row.canonicalDocumentSha256);
      assert.deepEqual(JSON.parse(raw), row.canonicalDocument);
      assert.equal(row.canonicalDocument.id, normalized);
      assert.equal(row.canonicalDocument.infusion, undefined);
      assert.equal(row.canonicalDocument.mc_gold_standard_v1.calculationAuthorized, false);
    }
  });
}
test('interaction grouping alias is not a canonical drug identity', () => {
  const row = fixture.bindings.find(x => x.fallback.nome === 'Nitroglicerina');
  assert.equal(row.recognizedNormalization.alias, 'isossorbida');
  assert.equal(ids.has('isossorbida'), false);
});
test('all existing presets remain adult-only, even with adult override on a child', () => {
  for (const row of fixture.bindings) {
    for (const age of [1, 17, NaN]) {
      const result = context.window.InfusionReviewSafety.evaluate({
        drug: row.fallback.nome, age, adultConfirmed: false,
      });
      assert.equal(result.errors.includes('adult'), true);
    }
    assert.equal(context.window.InfusionReviewSafety.evaluate({
      drug: row.fallback.nome, age: 1, adultConfirmed: true,
    }).errors.includes('adult'), true);
  }
});

function calculate(overrides = {}) {
  return math.calculate({amount: 1, volume: 1, weight: 1, dose: 1,
    unit: 'mg/h', amountUnit: 'mg', direction: 'dose', ...overrides});
}
for (const [unit, expected] of [['mcg/kg/min', .06], ['mcg/min', .06],
  ['mg/h', 1], ['mg/kg/h', 1], ['mcg/kg/h', .001], ['mg/min', 60], ['ml/h', 1]]) {
  test(`existing InfusionMath ${unit} → mL/h and reverse`, () => {
    const value = calculate({unit});
    assert.equal(value.error, undefined);
    assert.equal(value.rate, expected);
    const inverse = calculate({unit, direction: 'rate', rate: expected});
    assert.equal(inverse.error, undefined);
    assert.ok(Math.abs(inverse.dose - 1) < 1e-12);
  });
}
test('mg to mcg conversion remains exactly 1000x', () => {
  assert.equal(calculate({unit: 'mg/h'}).rate / calculate({unit: 'mcg/h'}).rate, 1000);
});
for (const invalid of [undefined, 0, -1, NaN, Infinity, -Infinity]) {
  test(`reject invalid amount/volume/weight/input: ${String(invalid)}`, () => {
    assert.equal(calculate({amount: invalid}).error, 'preparation');
    assert.equal(calculate({volume: invalid}).error, 'preparation');
    assert.equal(calculate({unit: 'mcg/kg/min', weight: invalid}).error, 'weight');
    assert.equal(calculate({dose: invalid}).error, 'input');
    assert.equal(calculate({direction: 'rate', rate: invalid}).error, 'input');
  });
}
test('UI cannot be treated as mass; unsupported units fail closed', () => {
  assert.equal(calculate({unit: 'UI/h', amountUnit: 'mg'}).error, 'unit');
  assert.equal(calculate({unit: 'mg/h', amountUnit: 'UI'}).error, 'unit');
  assert.equal(calculate({unit: 'unknown'}).error, 'unit');
  // g and mcg preparation masses are not accepted implicitly by this source.
  assert.equal(calculate({amountUnit: 'g'}).error, 'unit');
  assert.equal(calculate({amountUnit: 'mcg'}).error, 'unit');
});
test('overflow and underflow never return a valid pump rate', () => {
  assert.equal(calculate({dose: Number.MAX_VALUE, unit: 'mg/min'}).error, 'range');
  assert.equal(calculate({amount: Number.MIN_VALUE, volume: Number.MAX_VALUE}).error, 'range');
});
test('number parser rejects ambiguous or nonfinite data', () => {
  for (const value of ['', null, undefined, 'Infinity', 'NaN', '-1', '1,000.0', '1e3']) {
    assert.equal(Number.isNaN(math.number(value)), true);
  }
  assert.equal(math.number('1,5'), 1.5);
});

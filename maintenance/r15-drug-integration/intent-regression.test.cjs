'use strict';
// Existing adapter, deterministic local tests. No network, auth fabrication or
// clinical approval. The prepared directory contains the unchanged real handler.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const base = fs.readFileSync(path.join(__dirname, 'evidence/integration-candidate-path.txt'), 'utf8').trim();
const {resolveDrugReference, drugLookupIntent} = require(path.join(base, 'plantao_drug_reference'));
for (const query of ['Intoxicação por paracetamol', 'Intoxicación por paracetamol', 'Sobredosis de paracetamol', 'Dose de paracetamol em criança de 15 kg']) {
  test('not a general medication card: ' + query, async () => {
    let calls = 0;
    const result = await resolveDrugReference({query, language:'pt',
      data:{userMessage:query, catalogQuery:query, systemPrompt:'LOCAL_ONLY', history:[]},
      authorization:'Bearer SYNTHETIC_NOT_SENT', fetchImpl:()=>{ calls++; throw Error('NETWORK_FORBIDDEN'); }});
    assert.equal(result, null);
    assert.equal(calls, 0);
  });
}
test('strength qualifier resolves identity without authorizing that dose', () => {
  const intent = drugLookupIntent('Paracetamol 500 mg');
  assert.equal(intent.topic, 'paracetamol');
  assert.equal(intent.requestedStrength, '500 mg');
});
test('field-only question requires saved canonical identity', () => {
  assert.equal(drugLookupIntent('Como diluir?'), null);
  assert.equal(drugLookupIntent('Como diluir?', 'noradrenalina').topic, 'noradrenalina');
  assert.equal(drugLookupIntent('Qual o ajuste renal?', 'metformina').topic, 'metformina');
  assert.equal(drugLookupIntent('E quanto ao ajuste renal?', 'metformina').topic, 'metformina');
  assert.equal(drugLookupIntent('¿Y el ajuste renal?', 'metformina').topic, 'metformina');
});
test('named contraindications stay independent of prior drug', () => {
  const intent = drugLookupIntent('Contraindicações da ceftriaxona', 'paracetamol');
  assert.equal(intent.topic, 'ceftriaxona');
});

'use strict';

const assert = require('node:assert/strict');

const {
  IncrementalDisplayTextProjector,
  validateClinicalEnvelope,
} = require('../lib/structured_output_stream');

function projectWithChunkSizes(raw, sizes) {
  const projector = new IncrementalDisplayTextProjector();
  let visible = '';
  let offset = 0;
  let sizeIndex = 0;

  while (offset < raw.length) {
    const size = sizes[sizeIndex % sizes.length];
    const chunk = raw.slice(offset, offset + size);

    visible += projector.push(chunk);
    offset += size;
    sizeIndex += 1;
  }

  const envelope = projector.finish();

  return {
    visible,
    envelope,
  };
}

function expectThrows(fn, pattern) {
  assert.throws(fn, pattern);
}

/*
 * 1. Resposta educacional: structuredOutput=null.
 */
{
  const envelope = {
    displayText:
      'Resposta **completa**.\nAspas: "teste". Barra: \\.',
    structuredOutput: null,
  };

  const raw = JSON.stringify(envelope);

  for (const sizes of [
    [1],
    [2],
    [3, 1, 7, 2],
    [13],
  ]) {
    const result = projectWithChunkSizes(raw, sizes);

    assert.equal(result.visible, envelope.displayText);
    assert.deepEqual(result.envelope, envelope);
  }
}

/*
 * 2. Resposta clínica completa.
 */
{
  const envelope = {
    displayText:
      'Avaliação inicial e conduta priorizada.',
    structuredOutput: {
      diagnosticoHeuristico:
        'Síndrome clínica em investigação',
      condutaImediata:
        'Avaliar sinais vitais e causas ameaçadoras',
      prescricao: [
        {
          farmaco: 'Exemplo',
          posologia: 'Conforme contexto clínico',
        },
      ],
    },
  };

  const raw = JSON.stringify(envelope);
  const result = projectWithChunkSizes(
    raw,
    [1, 4, 2, 9],
  );

  assert.equal(result.visible, envelope.displayText);
  assert.deepEqual(result.envelope, envelope);
}

/*
 * 3. Ordem de propriedades invertida e conteúdo aninhado contendo
 *    a palavra displayText não pode confundir o projetor.
 */
{
  const raw =
    '{"structuredOutput":null,' +
    '"displayText":"Texto final correto"}';

  const result = projectWithChunkSizes(raw, [1]);

  assert.equal(result.visible, 'Texto final correto');
}

/*
 * 4. Unicode escapado, incluindo par substituto dividido byte a byte.
 */
{
  const raw =
    '{"displayText":"A\\u00E7\\u00E3o ' +
    '\\uD83E\\uDE7A","structuredOutput":null}';

  const result = projectWithChunkSizes(raw, [1]);

  assert.equal(result.visible, 'Ação 🩺');
  assert.equal(result.envelope.displayText, 'Ação 🩺');
}

/*
 * 5. Emoji literal UTF-8.
 */
{
  const envelope = {
    displayText: 'Clínica 🚑 segura',
    structuredOutput: null,
  };

  const raw = JSON.stringify(envelope);
  const result = projectWithChunkSizes(raw, [2, 1, 5]);

  assert.equal(result.visible, envelope.displayText);
}

/*
 * 6. displayText não textual deve falhar imediatamente.
 */
{
  const projector = new IncrementalDisplayTextProjector();

  expectThrows(
    () => projector.push(
      '{"displayText":null,"structuredOutput":null}',
    ),
    /display_text_not_string/,
  );
}

/*
 * 7. JSON truncado deve falhar no finish.
 */
{
  const projector = new IncrementalDisplayTextProjector();

  projector.push('{"displayText":"incompleto');

  expectThrows(
    () => projector.finish(),
    /incomplete_string/,
  );
}

/*
 * 8. structuredOutput inválido deve falhar na validação final.
 */
{
  expectThrows(
    () => validateClinicalEnvelope({
      displayText: 'Texto',
      structuredOutput: {},
    }),
    /invalid_keys:structuredOutput/,
  );
}

/*
 * 9. Propriedade adicional deve falhar.
 */
{
  expectThrows(
    () => validateClinicalEnvelope({
      displayText: 'Texto',
      structuredOutput: null,
      extra: true,
    }),
    /invalid_keys:envelope/,
  );
}

console.log('STRUCTURED_OUTPUT_STREAM_TESTS_OK');

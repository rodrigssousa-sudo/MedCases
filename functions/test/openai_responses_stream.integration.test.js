'use strict';

const assert = require('assert');
const { EventEmitter } = require('events');
const { spawnSync } = require('child_process');

const ROOT_MODE = !process.env.OPENAI_STREAM_TEST_CHILD;

if (ROOT_MODE) {
  const modes = ['structured', 'legacy'];

  for (const mode of modes) {
    const result = spawnSync(
      process.execPath,
      [__filename],
      {
        cwd: process.cwd(),
        env: {
          ...process.env,
          NODE_ENV: 'test',
          FIREBASE_CONFIG: JSON.stringify({
            projectId: 'medcases-pro',
          }),
          GCLOUD_PROJECT: 'medcases-pro',
          OPENAI_STREAM_TEST_CHILD: '1',
          OPENAI_STREAM_TEST_MODE: mode,
          USE_GPT_56_STRUCTURED_OUTPUTS:
            mode === 'structured' ? 'true' : 'false',
        },
        encoding: 'utf8',
      },
    );

    process.stdout.write(result.stdout);
    process.stderr.write(result.stderr);

    if (result.status !== 0) {
      process.exit(result.status || 1);
    }
  }

  console.log(
    'OPENAI_RESPONSES_STREAM_INTEGRATION_TESTS_OK',
  );

  process.exit(0);
}

const https = require('https');

class MockRequest extends EventEmitter {
  constructor(responseFactory, callback) {
    super();

    this.responseFactory = responseFactory;
    this.callback = callback;
    this.destroyed = false;
    this.body = '';
  }

  write(chunk) {
    this.body += String(chunk);
  }

  end() {
    process.nextTick(() => {
      if (this.destroyed) return;

      const response = this.responseFactory(this);
      this.callback(response);
      response.start();
    });
  }

  setTimeout() {}

  destroy(error) {
    if (this.destroyed) return;

    this.destroyed = true;

    if (error) {
      process.nextTick(() => {
        this.emit('error', error);
      });
    }
  }
}

class MockResponse extends EventEmitter {
  constructor({
    statusCode = 200,
    chunks = [],
    emitEnd = true,
  }) {
    super();

    this.statusCode = statusCode;
    this.chunks = chunks;
    this.emitEnd = emitEnd;
    this.destroyed = false;
  }

  start() {
    let index = 0;

    const emitNext = () => {
      if (
        this.destroyed ||
        index >= this.chunks.length
      ) {
        if (
          !this.destroyed &&
          this.emitEnd
        ) {
          this.emit('end');
        }

        return;
      }

      const chunk = this.chunks[index++];
      this.emit('data', Buffer.from(chunk, 'utf8'));

      setImmediate(emitNext);
    };

    setImmediate(emitNext);
  }

  destroy() {
    if (this.destroyed) return;

    this.destroyed = true;

    process.nextTick(() => {
      this.emit(
        'error',
        new Error('mock_response_destroyed'),
      );
    });
  }
}

const scenarioQueue = [];
const createdRequests = [];

https.request = (_options, callback) => {
  const scenario = scenarioQueue.shift();

  if (!scenario) {
    throw new Error(
      'MOCK_SCENARIO_QUEUE_EMPTY',
    );
  }

  const request = new MockRequest(
    scenario.responseFactory,
    callback,
  );

  createdRequests.push(request);

  return request;
};

const backend = require('../index.js');

assert.ok(
  backend.__test,
  'backend.__test ausente',
);

const {
  callOpenAiResponsesStream,
} = backend.__test;

function sse(event) {
  return `data: ${JSON.stringify(event)}\n\n`;
}

async function runScenario({
  name,
  chunks,
  expectedError,
  expectedDeltas,
  expectedText,
  validateResult,
}) {
  const deltas = [];

  scenarioQueue.push({
    responseFactory: () =>
      new MockResponse({
        chunks,
      }),
  });

  let result = null;
  let error = null;

  try {
    result = await callOpenAiResponsesStream({
      openAiKey: 'test-key',
      systemPrompt: 'Sistema de teste.',
      userMessage: 'Mensagem de teste.',
      history: [],
      maxOutputTokens: 200,
      requestId: `test-${name}`,
      onDelta: (event) => {
        deltas.push(event.delta);
      },
      abortSignal: null,
    });
  } catch (caught) {
    error = caught;
  }

  if (expectedError) {
    assert.ok(
      error,
      `${name}: deveria falhar`,
    );

    assert.ok(
      error.message.startsWith(expectedError),
      `${name}: erro inesperado: ${error.message}`,
    );

    assert.strictEqual(
      result,
      null,
      `${name}: não deveria resolver`,
    );
  } else {
    assert.ifError(error);
    assert.ok(
      result,
      `${name}: resultado ausente`,
    );

    validateResult(result);
  }

  if (expectedDeltas) {
    assert.deepStrictEqual(
      deltas,
      expectedDeltas,
      `${name}: deltas inesperados`,
    );
  }

  if (expectedText !== undefined) {
    assert.strictEqual(
      deltas.join(''),
      expectedText,
      `${name}: texto concatenado inesperado`,
    );
  }

  assert.strictEqual(
    scenarioQueue.length,
    0,
    `${name}: cenário não consumido`,
  );

  console.log(`OK ${name}`);
}

async function runStructuredTests() {
  const envelope = JSON.stringify({
    displayText: 'Resposta clínica segura.',
    structuredOutput: null,
  });

  await runScenario({
    name: 'structured_success',
    chunks: [
      sse({
        type: 'response.output_text.delta',
        delta: envelope.slice(0, 17),
      }),
      sse({
        type: 'response.output_text.delta',
        delta: envelope.slice(17),
      }),
      sse({
        type: 'response.output_text.done',
        text: envelope,
      }),
      sse({
        type: 'response.completed',
        response: {
          usage: {
            input_tokens: 14,
            output_tokens: 22,
          },
        },
      }),
    ],
    expectedError: null,
    expectedText: 'Resposta clínica segura.',
    validateResult: (result) => {
      assert.strictEqual(
        result.model,
        'gpt-5.6',
      );

      assert.strictEqual(
        result.provider,
        'gpt_5_6',
      );

      assert.strictEqual(
        result.structuredOutput,
        null,
      );

      assert.strictEqual(
        result.inputTokensApprox,
        14,
      );

      assert.strictEqual(
        result.outputTokensApprox,
        22,
      );
    },
  });

  await runScenario({
    name: 'structured_refusal',
    chunks: [
      sse({
        type: 'response.refusal.delta',
        delta: 'conteúdo que não deve vazar',
      }),
      sse({
        type: 'response.output_text.delta',
        delta: 'NÃO DEVE SER EMITIDO',
      }),
    ],
    expectedError: 'openai_refusal',
    expectedDeltas: [],
  });

  await runScenario({
    name: 'structured_incomplete',
    chunks: [
      sse({
        type: 'response.incomplete',
        response: {
          incomplete_details: {
            reason: 'max_output_tokens',
          },
        },
      }),
      sse({
        type: 'response.output_text.delta',
        delta: 'NÃO DEVE SER EMITIDO',
      }),
    ],
    expectedError: 'openai_incomplete:',
    expectedDeltas: [],
  });

  await runScenario({
    name: 'structured_failed',
    chunks: [
      sse({
        type: 'response.failed',
        message: 'mock_failure',
      }),
      sse({
        type: 'response.output_text.delta',
        delta: 'NÃO DEVE SER EMITIDO',
      }),
    ],
    expectedError: 'openai_failed:',
    expectedDeltas: [],
  });

  const truncated =
    '{"displayText":"Resposta truncada';

  await runScenario({
    name: 'structured_truncated_json',
    chunks: [
      sse({
        type: 'response.output_text.delta',
        delta: truncated,
      }),
      sse({
        type: 'response.completed',
        response: {
          usage: {},
        },
      }),
    ],
    expectedError: 'structured_',
    expectedDeltas: [
      'Resposta truncada',
    ],
  });

  const mismatchEnvelope = JSON.stringify({
    displayText: 'Texto A',
    structuredOutput: null,
  });

  const differentEnvelope = JSON.stringify({
    displayText: 'Texto B',
    structuredOutput: null,
  });

  await runScenario({
    name: 'structured_done_mismatch',
    chunks: [
      sse({
        type: 'response.output_text.delta',
        delta: mismatchEnvelope,
      }),
      sse({
        type: 'response.output_text.done',
        text: differentEnvelope,
      }),
    ],
    expectedError:
      'structured_output_done_mismatch',
    expectedDeltas: [
      'Texto A',
    ],
  });
}

async function runLegacyTests() {
  await runScenario({
    name: 'legacy_success',
    chunks: [
      sse({
        type: 'response.output_text.delta',
        delta: 'Resposta ',
      }),
      sse({
        type: 'response.output_text.delta',
        delta: 'legada.',
      }),
      sse({
        type: 'response.completed',
        response: {
          usage: {
            input_tokens: 9,
            output_tokens: 11,
          },
        },
      }),
    ],
    expectedError: null,
    expectedDeltas: [
      'Resposta ',
      'legada.',
    ],
    validateResult: (result) => {
      assert.strictEqual(
        result.model,
        'gpt-4o-mini',
      );

      assert.strictEqual(
        result.provider,
        'gpt_4o_mini',
      );

      assert.strictEqual(
        result.structuredOutput,
        null,
      );
    },
  });
}

(async () => {
  const mode =
    process.env.OPENAI_STREAM_TEST_MODE;

  if (mode === 'structured') {
    await runStructuredTests();
  } else if (mode === 'legacy') {
    await runLegacyTests();
  } else {
    throw new Error(
      `UNKNOWN_TEST_MODE:${mode}`,
    );
  }

  assert.ok(
    createdRequests.length > 0,
    'nenhuma requisição simulada criada',
  );

  console.log(
    `OPENAI_STREAM_${mode.toUpperCase()}_OK`,
  );
})().catch((error) => {
  console.error(error);
  process.exit(1);
});

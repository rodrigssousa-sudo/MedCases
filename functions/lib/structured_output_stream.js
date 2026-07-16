'use strict';

/**
 * IncrementalDisplayTextProjector
 *
 * Recebe fragmentos arbitrários do JSON produzido por Structured Outputs
 * e projeta somente o valor textual da propriedade top-level displayText.
 *
 * Não usa regex.
 * Não depende da divisão dos chunks.
 * Decodifica escapes JSON e pares substitutos Unicode.
 * O JSON completo continua sendo acumulado para validação final.
 */
class IncrementalDisplayTextProjector {
  constructor({ targetKey = 'displayText' } = {}) {
    this.targetKey = targetKey;

    this._rawJson = '';
    this._emittedText = '';

    this._depth = 0;
    this._rootSeen = false;
    this._rootClosed = false;

    this._inString = false;
    this._stringRole = null;
    this._stringBuffer = '';

    this._escapePending = false;
    this._unicodeDigits = null;
    this._pendingHighSurrogate = null;

    this._expectingTopLevelKey = false;
    this._expectingTopLevelColon = false;
    this._expectingTopLevelValue = false;
    this._currentTopLevelKey = null;

    this._displayTextFound = false;
    this._displayTextComplete = false;

    this._failed = false;
    this._finished = false;
  }

  get rawJson() {
    return this._rawJson;
  }

  get emittedText() {
    return this._emittedText;
  }

  get displayTextComplete() {
    return this._displayTextComplete;
  }

  /**
   * Processa um novo fragmento bruto de output_text.
   *
   * @returns {string} somente os novos caracteres legíveis de displayText.
   */
  push(chunk) {
    if (this._failed) {
      throw new Error('structured_projector_already_failed');
    }

    if (this._finished) {
      throw new Error('structured_projector_already_finished');
    }

    if (typeof chunk !== 'string') {
      return this._fail('structured_projector_chunk_not_string');
    }

    this._rawJson += chunk;

    const visibleParts = [];

    for (const character of chunk) {
      if (this._inString) {
        this._consumeStringCharacter(character, visibleParts);
        continue;
      }

      if (this._isWhitespace(character)) {
        continue;
      }

      /*
       * Esperando uma chave imediatamente dentro do objeto raiz.
       */
      if (this._depth === 1 && this._expectingTopLevelKey) {
        if (character === '}') {
          this._depth -= 1;
          this._rootClosed = true;
          this._expectingTopLevelKey = false;
          continue;
        }

        if (character !== '"') {
          return this._fail(
            `structured_projector_expected_top_level_key:${character}`,
          );
        }

        this._startString('top_level_key');
        continue;
      }

      /*
       * Esperando os dois pontos após uma chave top-level.
       */
      if (this._depth === 1 && this._expectingTopLevelColon) {
        if (character !== ':') {
          return this._fail(
            `structured_projector_expected_colon:${character}`,
          );
        }

        this._expectingTopLevelColon = false;
        this._expectingTopLevelValue = true;
        continue;
      }

      /*
       * Início do valor de uma propriedade top-level.
       */
      if (this._depth === 1 && this._expectingTopLevelValue) {
        const isDisplayText =
          this._currentTopLevelKey === this.targetKey;

        if (isDisplayText && character !== '"') {
          return this._fail(
            'structured_projector_display_text_not_string',
          );
        }

        this._expectingTopLevelValue = false;

        if (character === '"') {
          this._startString(
            isDisplayText
              ? 'display_text_value'
              : 'other_top_level_value',
          );
          continue;
        }

        /*
         * Valor não textual: objeto, array, null, número ou booleano.
         * O caractere ainda precisa passar pelo controle estrutural abaixo.
         */
      }

      /*
       * Strings aninhadas ou strings não relacionadas.
       */
      if (character === '"') {
        this._startString('other');
        continue;
      }

      if (character === '{') {
        this._depth += 1;

        if (!this._rootSeen) {
          this._rootSeen = true;

          if (this._depth !== 1) {
            return this._fail(
              'structured_projector_invalid_root_depth',
            );
          }

          this._expectingTopLevelKey = true;
        }

        continue;
      }

      if (character === '[') {
        this._depth += 1;
        continue;
      }

      if (character === '}' || character === ']') {
        this._depth -= 1;

        if (this._depth < 0) {
          return this._fail(
            'structured_projector_negative_depth',
          );
        }

        if (this._depth === 0) {
          this._rootClosed = true;
        }

        continue;
      }

      if (character === ',' && this._depth === 1) {
        this._currentTopLevelKey = null;
        this._expectingTopLevelKey = true;
        this._expectingTopLevelColon = false;
        this._expectingTopLevelValue = false;
      }
    }

    const visibleDelta = visibleParts.join('');
    this._emittedText += visibleDelta;

    return visibleDelta;
  }

  /**
   * Finaliza, faz JSON.parse e aplica validação server-side fail-closed.
   */
  finish() {
    if (this._failed) {
      throw new Error('structured_projector_already_failed');
    }

    if (this._finished) {
      throw new Error('structured_projector_already_finished');
    }

    this._finished = true;

    if (
      this._inString ||
      this._escapePending ||
      this._unicodeDigits !== null
    ) {
      return this._fail(
        'structured_projector_incomplete_string',
      );
    }

    if (this._pendingHighSurrogate !== null) {
      return this._fail(
        'structured_projector_incomplete_surrogate_pair',
      );
    }

    if (!this._rootSeen || !this._rootClosed) {
      return this._fail(
        'structured_projector_incomplete_root',
      );
    }

    if (
      !this._displayTextFound ||
      !this._displayTextComplete
    ) {
      return this._fail(
        'structured_projector_display_text_missing',
      );
    }

    let envelope;

    try {
      envelope = JSON.parse(this._rawJson);
    } catch (error) {
      return this._fail(
        `structured_projector_final_json_invalid:${error.message}`,
      );
    }

    validateClinicalEnvelope(envelope);

    /*
     * Barreira crítica:
     * o que foi mostrado incrementalmente deve ser exatamente igual ao
     * displayText validado no JSON final.
     */
    if (envelope.displayText !== this._emittedText) {
      return this._fail(
        'structured_projector_stream_final_mismatch',
      );
    }

    return envelope;
  }

  _startString(role) {
    this._inString = true;
    this._stringRole = role;
    this._stringBuffer = '';
    this._escapePending = false;
    this._unicodeDigits = null;
  }

  _consumeStringCharacter(character, visibleParts) {
    if (this._unicodeDigits !== null) {
      if (!/^[0-9a-fA-F]$/.test(character)) {
        return this._fail(
          `structured_projector_invalid_unicode_escape:${character}`,
        );
      }

      this._unicodeDigits += character;

      if (this._unicodeDigits.length === 4) {
        const codeUnit = Number.parseInt(
          this._unicodeDigits,
          16,
        );

        this._unicodeDigits = null;
        this._appendUnicodeCodeUnit(
          codeUnit,
          visibleParts,
        );
      }

      return;
    }

    if (this._escapePending) {
      this._escapePending = false;

      if (character === 'u') {
        this._unicodeDigits = '';
        return;
      }

      const escapes = {
        '"': '"',
        '\\': '\\',
        '/': '/',
        b: '\b',
        f: '\f',
        n: '\n',
        r: '\r',
        t: '\t',
      };

      if (!Object.prototype.hasOwnProperty.call(
        escapes,
        character,
      )) {
        return this._fail(
          `structured_projector_invalid_escape:${character}`,
        );
      }

      this._appendDecodedCharacter(
        escapes[character],
        visibleParts,
      );
      return;
    }

    if (character === '\\') {
      this._escapePending = true;
      return;
    }

    if (character === '"') {
      if (this._pendingHighSurrogate !== null) {
        return this._fail(
          'structured_projector_unpaired_high_surrogate',
        );
      }

      this._closeString();
      return;
    }

    if (
      character.length === 1 &&
      character.charCodeAt(0) < 0x20
    ) {
      return this._fail(
        'structured_projector_unescaped_control_character',
      );
    }

    this._appendDecodedCharacter(
      character,
      visibleParts,
    );
  }

  _appendUnicodeCodeUnit(codeUnit, visibleParts) {
    const isHigh =
      codeUnit >= 0xD800 && codeUnit <= 0xDBFF;

    const isLow =
      codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;

    if (this._stringRole !== 'display_text_value') {
      this._stringBuffer += String.fromCharCode(codeUnit);
      return;
    }

    if (isHigh) {
      if (this._pendingHighSurrogate !== null) {
        return this._fail(
          'structured_projector_repeated_high_surrogate',
        );
      }

      this._pendingHighSurrogate = codeUnit;
      return;
    }

    if (isLow) {
      if (this._pendingHighSurrogate === null) {
        return this._fail(
          'structured_projector_unpaired_low_surrogate',
        );
      }

      const high = this._pendingHighSurrogate;
      this._pendingHighSurrogate = null;

      const codePoint =
        0x10000 +
        ((high - 0xD800) << 10) +
        (codeUnit - 0xDC00);

      visibleParts.push(String.fromCodePoint(codePoint));
      return;
    }

    if (this._pendingHighSurrogate !== null) {
      return this._fail(
        'structured_projector_expected_low_surrogate',
      );
    }

    visibleParts.push(String.fromCharCode(codeUnit));
  }

  _appendDecodedCharacter(character, visibleParts) {
    if (this._stringRole === 'display_text_value') {
      if (this._pendingHighSurrogate !== null) {
        return this._fail(
          'structured_projector_expected_low_surrogate',
        );
      }

      visibleParts.push(character);
      return;
    }

    if (this._stringRole === 'top_level_key') {
      this._stringBuffer += character;
    }
  }

  _closeString() {
    const role = this._stringRole;

    this._inString = false;
    this._stringRole = null;
    this._escapePending = false;
    this._unicodeDigits = null;

    if (role === 'top_level_key') {
      this._currentTopLevelKey = this._stringBuffer;
      this._expectingTopLevelKey = false;
      this._expectingTopLevelColon = true;
      this._stringBuffer = '';
      return;
    }

    if (role === 'display_text_value') {
      this._displayTextFound = true;
      this._displayTextComplete = true;
      this._currentTopLevelKey = null;
      return;
    }

    if (role === 'other_top_level_value') {
      this._currentTopLevelKey = null;
    }
  }

  _isWhitespace(character) {
    return (
      character === ' ' ||
      character === '\n' ||
      character === '\r' ||
      character === '\t'
    );
  }

  _fail(code) {
    this._failed = true;
    throw new Error(code);
  }
}

function isPlainObject(value) {
  return (
    value !== null &&
    typeof value === 'object' &&
    !Array.isArray(value)
  );
}

function assertExactKeys(value, expectedKeys, label) {
  const actual = Object.keys(value).sort();
  const expected = [...expectedKeys].sort();

  if (
    actual.length !== expected.length ||
    actual.some((key, index) => key !== expected[index])
  ) {
    throw new Error(
      `structured_validation_invalid_keys:${label}`,
    );
  }
}

/**
 * Defesa server-side adicional.
 *
 * Structured Outputs já restringe o modelo, porém o backend continua
 * validando o envelope antes de considerá-lo clinicamente utilizável.
 */
function validateClinicalEnvelope(envelope) {
  if (!isPlainObject(envelope)) {
    throw new Error(
      'structured_validation_envelope_not_object',
    );
  }

  assertExactKeys(
    envelope,
    ['displayText', 'structuredOutput'],
    'envelope',
  );

  if (
    typeof envelope.displayText !== 'string' ||
    envelope.displayText.trim().length === 0
  ) {
    throw new Error(
      'structured_validation_display_text_invalid',
    );
  }

  const structured = envelope.structuredOutput;

  if (structured === null) {
    return envelope;
  }

  if (!isPlainObject(structured)) {
    throw new Error(
      'structured_validation_structured_output_invalid',
    );
  }

  assertExactKeys(
    structured,
    [
      'diagnosticoHeuristico',
      'condutaImediata',
      'prescricao',
    ],
    'structuredOutput',
  );

  for (const field of [
    'diagnosticoHeuristico',
    'condutaImediata',
  ]) {
    if (
      typeof structured[field] !== 'string' ||
      structured[field].trim().length === 0
    ) {
      throw new Error(
        `structured_validation_invalid_field:${field}`,
      );
    }
  }

  if (!Array.isArray(structured.prescricao)) {
    throw new Error(
      'structured_validation_prescricao_not_array',
    );
  }

  structured.prescricao.forEach((item, index) => {
    if (!isPlainObject(item)) {
      throw new Error(
        `structured_validation_prescricao_item_invalid:${index}`,
      );
    }

    assertExactKeys(
      item,
      ['farmaco', 'posologia'],
      `prescricao[${index}]`,
    );

    for (const field of ['farmaco', 'posologia']) {
      if (
        typeof item[field] !== 'string' ||
        item[field].trim().length === 0
      ) {
        throw new Error(
          `structured_validation_prescricao_field_invalid:${index}:${field}`,
        );
      }
    }
  });

  return envelope;
}

module.exports = {
  IncrementalDisplayTextProjector,
  validateClinicalEnvelope,
};

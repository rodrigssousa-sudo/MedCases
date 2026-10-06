import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_smart_router.dart';
import 'package:medcases/services/gemini_service_v2.dart';

const studyLeakFixture = "Let's review constraints:\n"
    'Language: Spanish (es-ES) -> Checked.\n'
    'Anti-\n\n'
    '# Síndrome nefrótico\n\n'
    '## Concepto\n\n'
    'Texto didáctico sintético completo.\n\n'
    'Line 17: ## Mecanismo\n\n'
    'Explicación sintética del mecanismo.\n\n'
    '## Resumen\n\n'
    'Resumen sintético completo.';

void main() {
  test('physical internal strings do not survive Study terminal sanitation',
      () {
    final result = AiSmartRouter.sanitizeAndCheck(studyLeakFixture,
        isPlantaoMode: false, appLanguage: 'es');
    for (final marker in [
      "Let's review constraints",
      'Language: Spanish',
      'Checked.',
      'Line 17:',
      'Anti-'
    ]) {
      expect(result.text, isNot(contains(marker)));
    }
    expect(result.text, contains('# Síndrome nefrótico'));
    expect(result.text, contains('## Mecanismo'));
    expect(result.text, contains('Resumen sintético completo.'));
  });

  test('provider-channel origin can be reproduced without UI concatenation',
      () async {
    final wire = 'data: ${jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': studyLeakFixture}
                ]
              },
              'finishReason': 'STOP'
            }
          ]
        })}\n\n';
    final chunks = await GeminiServiceV2.decodeResponseForTesting(
            Stream.value(utf8.encode(wire)))
        .toList();
    final raw = chunks.map((c) => c.text).join();
    expect(raw, contains("Let's review constraints"));
    expect(raw, contains('Line 17:'));
    final finalText = AiSmartRouter.sanitizeAndCheck(raw,
            isPlantaoMode: false, appLanguage: 'es')
        .text;
    expect(finalText, isNot(contains("Let's review constraints")));
  });
}

import 'package:flutter_test/flutter_test.dart';

import '../../lib/services/study_continuation_resolver.dart';

void main() {
  group('R18.6AA-R1F-R3 — StudyContinuationResolver', () {
    test('tag remota válida possui precedência', () {
      final result = StudyContinuationResolver.resolve(
        rawText: '''
## Insuficiência renal aguda

Clínica e diagnóstico.

[NEXT_ACTION_LABEL: Manejo inicial]
[NEXT_ACTION_PROMPT: ¿Cómo se realiza el manejo inicial de la LRA?]
''',
        isStudyMode: true,
        isSafeCard: false,
        isStreaming: false,
        lastUserMessage: 'Explícame la insuficiencia renal aguda.',
        languageCode: 'es',
      );

      expect(
        result.source,
        StudyContinuationSource.remoteTag,
      );

      expect(
        result.question,
        '¿Cómo se realiza el manejo inicial de la LRA?',
      );

      expect(
        result.displayText,
        isNot(contains('NEXT_ACTION_')),
      );
    });

    test('sem tag usa motor local ou fallback genérico', () {
      final result = StudyContinuationResolver.resolve(
        rawText: '''
## Insuficiência renal aguda

Redução aguda da taxa de filtração glomerular.
''',
        isStudyMode: true,
        isSafeCard: false,
        isStreaming: false,
        lastUserMessage: 'Explique insuficiência renal aguda.',
        languageCode: 'pt',
      );

      expect(result.hasContinuation, isTrue);
      expect(result.question, endsWith('?'));

      expect(
        result.source,
        anyOf(
          StudyContinuationSource.localEngine,
          StudyContinuationSource.genericFallback,
        ),
      );
    });

    test('remove frase antiga com pin e cria botão', () {
      final result = StudyContinuationResolver.resolve(
        rawText: '''
## Síndrome cerebeloso

Clínica, investigação e diferenciais.

📌 Me gustaría saber más sobre las causas específicas del síndrome cerebeloso.
''',
        isStudyMode: true,
        isSafeCard: false,
        isStreaming: false,
        lastUserMessage: 'Explícame el síndrome cerebeloso.',
        languageCode: 'es',
      );

      expect(
        result.displayText,
        isNot(contains('Me gustaría saber más')),
      );

      expect(
        result.displayText,
        isNot(contains('📌')),
      );

      expect(result.hasContinuation, isTrue);
      expect(result.question, startsWith('¿'));
      expect(result.question, endsWith('?'));
    });

    test('não produz continuação durante streaming', () {
      final result = StudyContinuationResolver.resolve(
        rawText: 'Texto clínico parcial',
        isStudyMode: true,
        isSafeCard: false,
        isStreaming: true,
        lastUserMessage: 'Explique sepse.',
        languageCode: 'pt',
      );

      expect(result.hasContinuation, isFalse);

      expect(
        result.source,
        StudyContinuationSource.none,
      );
    });

    test('safe-card nunca recebe continuação', () {
      final result = StudyContinuationResolver.resolve(
        rawText: 'Não consegui completar a resposta agora.',
        isStudyMode: true,
        isSafeCard: true,
        isStreaming: false,
        lastUserMessage: 'Explique sepse.',
        languageCode: 'pt',
      );

      expect(result.hasContinuation, isFalse);

      expect(
        result.source,
        StudyContinuationSource.none,
      );
    });

    test('Plantão permanece sem continuação pedagógica', () {
      const text = '📌 Monitorar: creatinina.';

      final result = StudyContinuationResolver.resolve(
        rawText: text,
        isStudyMode: false,
        isSafeCard: false,
        isStreaming: false,
        lastUserMessage: 'Conduta para IRA.',
        languageCode: 'pt',
      );

      expect(result.displayText, text);
      expect(result.hasContinuation, isFalse);
    });

    test('prompt remoto repetido não cria loop', () {
      const repeated =
          'Como realizar o manejo inicial da insuficiência renal aguda?';

      final result = StudyContinuationResolver.resolve(
        rawText: '''
Texto clínico.

[NEXT_ACTION_LABEL: Manejo inicial]
[NEXT_ACTION_PROMPT: $repeated]
''',
        isStudyMode: true,
        isSafeCard: false,
        isStreaming: false,
        lastUserMessage: 'Explique insuficiência renal aguda.',
        languageCode: 'pt',
        lastSentPrompt: repeated,
      );

      expect(result.hasContinuation, isTrue);
      expect(result.question, isNot(repeated));
    });
  });
}

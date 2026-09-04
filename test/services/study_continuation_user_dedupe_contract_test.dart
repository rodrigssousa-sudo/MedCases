import 'package:flutter_test/flutter_test.dart';

import '../../lib/services/study_continuation_resolver.dart';

void main() {
  group(
    'R18.6AC-R1B-H2B1 — deduplicação da pergunta original',
    () {
      test('tag remota igual ao usuário é rejeitada em PT', () {
        final result = StudyContinuationResolver.resolve(
          rawText: '''
Resposta clínica final.

[NEXT_ACTION_LABEL: Fisiologia detalhada]
[NEXT_ACTION_PROMPT: Fisiologia detalhada]
''',
          isStudyMode: true,
          isSafeCard: false,
          isStreaming: false,
          lastUserMessage: 'Explique fisiologia detalhada.',
          languageCode: 'pt',
        );

        expect(result.hasContinuation, isTrue);

        expect(
          result.question.toLowerCase(),
          isNot(
            contains('fisiologia detalhada?'),
          ),
        );
      });

      test('wrapper local que incorpora pergunta espanhola é rejeitado', () {
        final result = StudyContinuationResolver.resolve(
          rawText: '''
Respuesta clínica final.

[NEXT_ACTION_LABEL: Fisiología detallada]
[NEXT_ACTION_PROMPT: Explica la fisiología detallada]
''',
          isStudyMode: true,
          isSafeCard: false,
          isStreaming: false,
          lastUserMessage: '¿Explica la fisiología detallada?',
          languageCode: 'es',
        );

        expect(result.hasContinuation, isTrue);

        expect(
          result.source,
          StudyContinuationSource.genericFallback,
        );

        expect(
          result.question.toLowerCase(),
          isNot(
            contains(
              'explica la fisiología detallada',
            ),
          ),
        );

        expect(
          result.question,
          startsWith('¿'),
        );
      });

      test('wrapper português que contém a pergunta é rejeitado', () {
        final result = StudyContinuationResolver.resolve(
          rawText: '''
Resposta clínica final.

[NEXT_ACTION_LABEL: Detalhar]
[NEXT_ACTION_PROMPT: Explique fisiologia detalhada]
''',
          isStudyMode: true,
          isSafeCard: false,
          isStreaming: false,
          lastUserMessage: 'Pode me explicar a fisiologia detalhada?',
          languageCode: 'pt',
        );

        expect(result.hasContinuation, isTrue);

        expect(
          result.question.toLowerCase(),
          isNot(
            contains(
              'explique fisiologia detalhada',
            ),
          ),
        );
      });

      test('tema curto não causa bloqueio por contenção ampla', () {
        final result = StudyContinuationResolver.resolve(
          rawText: '''
Resposta clínica final.

[NEXT_ACTION_LABEL: Diagnóstico diferencial]
[NEXT_ACTION_PROMPT: Quais são os diagnósticos diferenciais de asma]
''',
          isStudyMode: true,
          isSafeCard: false,
          isStreaming: false,
          lastUserMessage: 'Asma',
          languageCode: 'pt',
        );

        expect(
          result.source,
          StudyContinuationSource.remoteTag,
        );
      });

      test('streaming continua sem botão', () {
        final result = StudyContinuationResolver.resolve(
          rawText: 'Resposta parcial',
          isStudyMode: true,
          isSafeCard: false,
          isStreaming: true,
          lastUserMessage: 'Hipercalemia',
          languageCode: 'pt',
        );

        expect(result.hasContinuation, isFalse);
        expect(result.source, StudyContinuationSource.none);
      });
    },
  );
}

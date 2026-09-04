import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/study_continuation_resolver.dart';

void main() {
  group('R13 Study continuation semantic binding', () {
    test('rejects physiology label paired with dose prompt', () {
      final result = StudyContinuationResolver.resolve(
        rawText: '''
## Asma
Texto educativo.
[NEXT_ACTION_LABEL: Profundizar fisiopatología]
[NEXT_ACTION_PROMPT: ¿Cuáles son las dosis específicas de los fármacos para el asma?]
''',
        isStudyMode: true,
        isSafeCard: false,
        isStreaming: false,
        lastUserMessage: 'Explícame el asma.',
        languageCode: 'es',
      );
      expect(result.source, isNot(StudyContinuationSource.remoteTag));
    });

    test('rejects meta-choice remote prompt', () {
      final result = StudyContinuationResolver.resolve(
        rawText: '''
## Asma
Texto educativo.
[NEXT_ACTION_LABEL: Dosis específicas]
[NEXT_ACTION_PROMPT: ¿Te gustaría que detalle las dosis específicas o prefieres criterios diagnósticos?]
''',
        isStudyMode: true,
        isSafeCard: false,
        isStreaming: false,
        lastUserMessage: 'Explícame el tratamiento del asma.',
        languageCode: 'es',
      );
      expect(result.source, isNot(StudyContinuationSource.remoteTag));
    });

    test('accepts coherent direct dose pair', () {
      final result = StudyContinuationResolver.resolve(
        rawText: '''
## Asma
Texto educativo.
[NEXT_ACTION_LABEL: Dosis específicas]
[NEXT_ACTION_PROMPT: ¿Cuáles son las dosis específicas de los principales fármacos para el asma?]
''',
        isStudyMode: true,
        isSafeCard: false,
        isStreaming: false,
        lastUserMessage: 'Explícame el tratamiento del asma.',
        languageCode: 'es',
      );
      expect(result.source, StudyContinuationSource.remoteTag);
      expect(result.label.toLowerCase(), contains('dosis'));
      expect(result.question.toLowerCase(), contains('dosis'));
    });

    test('unknown semantic family remains compatible', () {
      final result = StudyContinuationResolver.resolve(
        rawText: '''
## Asma
Texto educativo.
[NEXT_ACTION_LABEL: Punto clave]
[NEXT_ACTION_PROMPT: ¿Cómo se relaciona este tema con la práctica clínica?]
''',
        isStudyMode: true,
        isSafeCard: false,
        isStreaming: false,
        lastUserMessage: 'Explícame el asma.',
        languageCode: 'es',
      );
      expect(result.source, StudyContinuationSource.remoteTag);
    });
  });
}

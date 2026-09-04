import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/study_continuation_resolver.dart';

void main() {
  group('R20 Study continuation semantic repeat gate', () {
    test('remote physiology is rejected if physiology was already covered', () {
      final result = StudyContinuationResolver.resolve(
        rawText: '''
## Asma
### Fisiopatología
Inflamación crónica, hiperreactividad bronquial y obstrucción variable.

[NEXT_ACTION_LABEL: Profundizar fisiopatología]
[NEXT_ACTION_PROMPT: Explica la fisiopatología del asma con más detalle.]
''',
        isStudyMode: true,
        isSafeCard: false,
        isStreaming: false,
        lastUserMessage: 'Explícame el asma',
        languageCode: 'es',
        chatHistory: const <String>['Explícame el asma'],
      );

      expect(
        result.source,
        isNot(StudyContinuationSource.remoteTag),
      );
      expect(result.label.toLowerCase(), isNot(contains('fisiopat')));
    });

    test('uncovered diagnostic remote action stays authoritative', () {
      final result = StudyContinuationResolver.resolve(
        rawText: '''
## Asma
Conceptos generales del asma.

[NEXT_ACTION_LABEL: Criterios diagnósticos]
[NEXT_ACTION_PROMPT: Explica los criterios diagnósticos del asma.]
''',
        isStudyMode: true,
        isSafeCard: false,
        isStreaming: false,
        lastUserMessage: 'Asma',
        languageCode: 'es',
        chatHistory: const <String>['Asma'],
      );

      expect(result.source, StudyContinuationSource.remoteTag);
      expect(result.label.toLowerCase(), contains('diagn'));
    });
  });
}

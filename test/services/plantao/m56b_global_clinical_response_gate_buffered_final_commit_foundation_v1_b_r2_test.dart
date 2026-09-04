import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/plantao_global_clinical_response_gate.dart';

void main() {
  group('M56B Global Clinical Response Gate foundation', () {
    test('promotes disease identity above generic task heading', () {
      final result = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
        userText: 'Caso clínico',
        rawText: '''
CONDUCTA CLÍNICA INMEDIATA
ANAFILAXIA

Tratamiento farmacológico:
- Adrenalina IM.

Conducta inmediata:
- ABC y adrenalina IM.

RED FLAGS:
- Shock persistente.

Puntos clave:
- Reevaluar.
''',
        language: 'es',
      );

      expect(result.finalText.split('\n').first, 'ANAFILAXIA');
      expect(
        result.finalText.indexOf('Conducta inmediata'),
        lessThan(result.finalText.indexOf('Tratamiento farmacológico')),
      );
      expect(
        result.finalText.indexOf('Puntos clave'),
        lessThan(result.finalText.indexOf('RED FLAGS')),
      );
    });

    test('classification table body is preserved while sections reorder', () {
      final result = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
        userText: 'IAM',
        rawText: '''
IAMCEST

Clasificación:
| Criterio / clasificación | Resultado en este paciente |
| --- | --- |
| Killip | I |

Conducta inmediata:
- Reperfusión.
''',
        language: 'es',
      );
      expect(result.finalText, contains('| Killip | I |'));
      expect(
        result.finalText.indexOf('Conducta inmediata'),
        lessThan(result.finalText.indexOf('Clasificación')),
      );
    });

    test(
      'machine-native required and prohibited action validation is generic',
      () {
        const pack = PlantaoGlobalClinicalContextPack(
          pathologyKey: 'anafilaxia',
          protocolKey: 'anafilaxia',
          authoritative: true,
          requiredActions: <String>['adrenalina im'],
          prohibitedActions: <String>['corticoide de rutina'],
        );

        final ok = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
          userText: 'anafilaxia',
          rawText: '''
ANAFILAXIA

Conducta inmediata:
- Adrenalina IM inmediatamente.
''',
          language: 'es',
          contextPack: pack,
        );
        expect(ok.hasCriticalIssue, isFalse);
        expect(ok.machineAuthorityEvaluated, isTrue);

        final bad = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
          userText: 'anafilaxia',
          rawText: '''
ANAFILAXIA

Conducta inmediata:
- Corticoide de rutina.
''',
          language: 'es',
          contextPack: pack,
        );
        expect(
          bad.issues.any((issue) => issue.code == 'required_action_missing'),
          isTrue,
        );
        expect(
          bad.issues.any((issue) => issue.code == 'prohibited_action_present'),
          isTrue,
        );
      },
    );

    test(
      'source contract buffers Plantão chunks but preserves Study stream',
      () {
        final source = File('lib/screens/ai_screen.dart').readAsStringSync();
        final start = source.indexOf('onChunk: (accumulated) {');
        final end = source.indexOf('onDone: (finalText) {', start);
        expect(start, greaterThanOrEqualTo(0));
        expect(end, greaterThan(start));

        final chunk = source.substring(start, end);
        expect(chunk, contains('M56B_BUFFERED_FINAL_COMMIT'));
        expect(chunk, contains('if (!_longResponse) {'));
        expect(chunk, contains('m56bBufferedPlantaoText = accumulated;'));
        expect(chunk, contains('stage=chunk_buffered visible=false'));
        expect(chunk, contains('return;'));
        expect(chunk, contains('_streamingTextNotifier'));
      },
    );

    test('global prompt contract is injected once', () {
      final source = File('lib/services/ai_service.dart').readAsStringSync();
      expect(
        '[M56B_GLOBAL_CLINICAL_RESPONSE_CONTRACT]'.allMatches(source).length,
        1,
      );
      expect(source, contains('requiredFacts'));
      expect(source, contains('contraindicatedActions'));
      expect(source, contains('guidelineVersion'));
      expect(source, contains('ORDEN GLOBAL VISIBLE'));
    });

    test('final gate is after existing Plantão aesthetic finalizer', () {
      final source = File('lib/screens/ai_screen.dart').readAsStringSync();
      final aesthetic = source.indexOf(
        '_applyPlantaoAestheticGuard(safeFinalText)',
      );
      final gate = source.indexOf(
        'PlantaoGlobalClinicalResponseGate.finalizeForPresentation(',
        aesthetic,
      );
      expect(aesthetic, isNonNegative);
      expect(gate, greaterThan(aesthetic));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/plantao_global_clinical_response_gate.dart';

PlantaoGlobalClinicalContextPack fixturePack({
  required List<String> required,
  List<String> prohibited = const <String>[],
}) {
  return PlantaoGlobalClinicalContextPack(
    pathologyKey: 'matcher_fixture',
    protocolKey: 'matcher_fixture_protocol',
    guidelineVersion: '2026.1',
    clinicalReviewDate: '2026-09-01',
    requiredActions: required,
    prohibitedActions: prohibited,
    conditionalActions: const <String>[],
    classificationDependencies: const <String>[],
    scoreDependencies: const <String>[],
    authoritative: true,
  );
}

void main() {
  group('M56C R6 global action matcher V3', () {
    test('long multi-clause required action passes verbatim line match', () {
      const action =
          'Administrar tratamiento inicial; monitorizar respuesta, '
          'reevaluar perfusión y escalar si persiste inestabilidad.';
      final result = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
        userText: 'matcher fixture',
        rawText:
            'MATCHER FIXTURE\n\n'
            'Conducta inmediata\n'
            '- $action\n',
        language: 'es',
        contextPack: fixturePack(required: const <String>[action]),
      );

      expect(
        result.issues.where((issue) => issue.code == 'required_action_missing'),
        isEmpty,
      );
    });

    test('Portuguese preposition no does not become negation', () {
      const action = 'cristaloide isotônico rápido no choque';
      final result = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
        userText: 'matcher fixture',
        rawText:
            'MATCHER FIXTURE\n\n'
            'Conducta inmediata\n'
            '- Acceso IV con cristaloide isotónico rápido por shock.\n',
        language: 'es',
        contextPack: fixturePack(required: const <String>[action]),
      );

      expect(
        result.issues.where((issue) => issue.code == 'required_action_missing'),
        isEmpty,
      );
    });

    test('negated positive required action remains missing', () {
      const action = 'Administrar adrenalina IM inmediatamente';
      final result = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
        userText: 'matcher fixture',
        rawText:
            'MATCHER FIXTURE\n\n'
            'Conducta inmediata\n'
            '- No administrar adrenalina IM inmediatamente.\n',
        language: 'es',
        contextPack: fixturePack(required: const <String>[action]),
      );

      expect(
        result.issues.any((issue) => issue.code == 'required_action_missing'),
        isTrue,
      );
    });

    test('negated positive required cannot leak polarity after semicolon', () {
      const action =
          'Administrar vasopresor; titular según perfusión y respuesta';
      final result = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
        userText: 'matcher fixture',
        rawText:
            'MATCHER FIXTURE\n\n'
            'Conducta inmediata\n'
            '- No administrar vasopresor; titular según perfusión y respuesta.\n',
        language: 'es',
        contextPack: fixturePack(required: const <String>[action]),
      );

      expect(
        result.issues.any((issue) => issue.code == 'required_action_missing'),
        isTrue,
      );
    });

    test('authored negative required directive is satisfiable as negative', () {
      const action = 'No retrasar la terapia definitiva';
      final result = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
        userText: 'matcher fixture',
        rawText:
            'MATCHER FIXTURE\n\n'
            'Conducta inmediata\n'
            '- No retrasar la terapia definitiva.\n',
        language: 'es',
        contextPack: fixturePack(required: const <String>[action]),
      );

      expect(
        result.issues.where((issue) => issue.code == 'required_action_missing'),
        isEmpty,
      );
    });

    test('positive inversion cannot satisfy negative required directive', () {
      const action = 'No retrasar la terapia definitiva';
      final result = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
        userText: 'matcher fixture',
        rawText:
            'MATCHER FIXTURE\n\n'
            'Conducta inmediata\n'
            '- Retrasar la terapia definitiva.\n',
        language: 'es',
        contextPack: fixturePack(required: const <String>[action]),
      );

      expect(
        result.issues.any((issue) => issue.code == 'required_action_missing'),
        isTrue,
      );
    });

    test('negative recommendation punctuation remains negative', () {
      const prohibited = 'corticoide de rotina';

      for (final suffix in <String>['.', ';', ':', '!']) {
        final result =
            PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
              userText: 'matcher fixture',
              rawText:
                  'MATCHER FIXTURE\n\n'
                  'Puntos clave\n'
                  '- Corticoides no son de rutina$suffix\n',
              language: 'es',
              contextPack: fixturePack(
                required: const <String>['Monitorizar al paciente'],
                prohibited: const <String>[prohibited],
              ),
            );

        expect(
          result.issues.any(
            (issue) => issue.code == 'prohibited_action_present',
          ),
          isFalse,
          reason: 'suffix=$suffix',
        );
      }
    });

    test('internal no son de rutina is explicit negative guidance', () {
      const prohibited = 'corticoide de rotina';
      final result = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
        userText: 'matcher fixture',
        rawText:
            'MATCHER FIXTURE\n\n'
            'Puntos clave\n'
            '- Corticoides no son de rutina.\n',
        language: 'es',
        contextPack: fixturePack(
          required: const <String>['Monitorizar al paciente'],
          prohibited: const <String>[prohibited],
        ),
      );

      expect(
        result.issues.any((issue) => issue.code == 'prohibited_action_present'),
        isFalse,
      );
    });

    test(
      'negative prohibited guidance is safe; positive action is detected',
      () {
        const prohibited = 'No administrar AINEs';

        final safe = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
          userText: 'matcher fixture',
          rawText:
              'MATCHER FIXTURE\n\n'
              'Puntos clave\n'
              '- No administrar AINEs.\n',
          language: 'es',
          contextPack: fixturePack(
            required: const <String>['Monitorizar al paciente'],
            prohibited: const <String>[prohibited],
          ),
        );
        expect(
          safe.issues.any((issue) => issue.code == 'prohibited_action_present'),
          isFalse,
        );

        final unsafe =
            PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
              userText: 'matcher fixture',
              rawText:
                  'MATCHER FIXTURE\n\n'
                  'Conducta inmediata\n'
                  '- Administrar AINEs.\n',
              language: 'es',
              contextPack: fixturePack(
                required: const <String>['Monitorizar al paciente'],
                prohibited: const <String>[prohibited],
              ),
            );
        expect(
          unsafe.issues.any(
            (issue) => issue.code == 'prohibited_action_present',
          ),
          isTrue,
        );
      },
    );
  });
}

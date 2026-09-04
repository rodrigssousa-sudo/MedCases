import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_treatment_presentation.dart';
import 'package:medcases/services/ai_pipeline/clinical_treatment_presentation_adapter.dart';

void main() {
  group('PHASE3I-J2F2 explicit conservative adapter', () {
    test('parses concomitant treatment only from explicit heading', () {
      final result = ClinicalTreatmentPresentationAdapter.fromExplicitText(
        '''
Tratamento inicial combinado:
- AAS 300 mg VO
- Clopidogrel 300 mg VO
''',
      );

      expect(
        result
            .itemsFor(ClinicalTreatmentRelation.concomitant)
            .map((item) => item.text),
        orderedEquals(<String>[
          'AAS 300 mg VO',
          'Clopidogrel 300 mg VO',
        ]),
      );
    });

    test('parses all authorized relation headings in PT and ES', () {
      final result = ClinicalTreatmentPresentationAdapter.fromExplicitText(
        '''
Alternativas terapêuticas:
- Ticagrelor 180 mg VO
Uso condicional:
- Nitrato se pressão permitir
Terapia adjuvante:
- Analgesia conforme dor
Terapia de resgate:
- Vasopressor se choque
Próxima etapa:
- Transferir para hemodinâmica
Contraindicado:
- Nitrato com PAS menor de 90 mmHg
Tratamiento combinado:
- AAS 300 mg VO
''',
      );

      for (final relation in <ClinicalTreatmentRelation>[
        ClinicalTreatmentRelation.alternative,
        ClinicalTreatmentRelation.conditional,
        ClinicalTreatmentRelation.adjunct,
        ClinicalTreatmentRelation.rescue,
        ClinicalTreatmentRelation.sequenceStep,
        ClinicalTreatmentRelation.contraindicated,
        ClinicalTreatmentRelation.concomitant,
      ]) {
        expect(
          result.itemsFor(relation),
          hasLength(1),
          reason: 'Relação ausente: ${relation.name}',
        );
      }
    });

    test('parses alert and hard stop as distinct safety flags', () {
      final result = ClinicalTreatmentPresentationAdapter.fromExplicitText(
        '''
Alerta clínico:
- Monitorar hipotensão
HARD STOP:
- Não administrar nitrato com PAS menor de 90 mmHg
''',
      );

      expect(
        result.flagsFor(ClinicalSafetyFlagType.alert).single.text,
        'Monitorar hipotensão',
      );
      expect(
        result.flagsFor(ClinicalSafetyFlagType.hardStop).single.text,
        'Não administrar nitrato com PAS menor de 90 mmHg',
      );
    });

    test('supports inline headings', () {
      final result = ClinicalTreatmentPresentationAdapter.fromExplicitText(
        '''
Uso condicional: Nitrato somente se PA permitir
HARD STOP: Não usar nitrato com hipotensão
''',
      );

      expect(
        result.itemsFor(ClinicalTreatmentRelation.conditional).single.text,
        'Nitrato somente se PA permitir',
      );
      expect(
        result.flagsFor(ClinicalSafetyFlagType.hardStop).single.text,
        'Não usar nitrato com hipotensão',
      );
    });

    test('does not promote first and second line', () {
      final result = ClinicalTreatmentPresentationAdapter.fromExplicitText(
        '''
1ª linha:
- AAS 300 mg VO
- Clopidogrel 300 mg VO
2ª linha:
- Morfina se dor refratária
''',
      );

      expect(result.items, isEmpty);
      expect(result.safetyFlags, isEmpty);
    });

    test('does not classify generic pharmacologic headings', () {
      final result = ClinicalTreatmentPresentationAdapter.fromExplicitText(
        '''
Tratamento farmacológico:
- AAS 300 mg VO
- Clopidogrel 300 mg VO
''',
      );

      expect(result.items, isEmpty);
    });

    test('does not infer a relation from item wording alone', () {
      final result = ClinicalTreatmentPresentationAdapter.fromExplicitText(
        '''
- Usar nitrato se pressão permitir
- Evitar nitrato com hipotensão
- Analgesia se dor refratária
''',
      );

      expect(result.items, isEmpty);
      expect(result.safetyFlags, isEmpty);
    });

    test('deduplicates only within the same relation', () {
      final result = ClinicalTreatmentPresentationAdapter.fromExplicitText(
        '''
Tratamento combinado:
- AAS 300 mg VO
- AAS 300 mg VO
Alternativas:
- AAS 300 mg VO
''',
      );

      expect(
        result.itemsFor(ClinicalTreatmentRelation.concomitant),
        hasLength(1),
      );
      expect(
        result.itemsFor(ClinicalTreatmentRelation.alternative),
        hasLength(1),
      );
    });

    test('empty text produces empty presentation', () {
      final result =
          ClinicalTreatmentPresentationAdapter.fromExplicitText('   ');

      expect(result.isEmpty, isTrue);
    });

    test('adapter remains disconnected from productive owners', () {
      final structured = File(
        'lib/models/clinical_structured_output.dart',
      ).readAsStringSync();
      final localAdapter = File(
        'lib/services/ai_pipeline/plantao_local_clinical_output_adapter.dart',
      ).readAsStringSync();
      final renderer = File(
        'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
      ).readAsStringSync();
      final provider = File(
        'lib/providers/app_provider.dart',
      ).readAsStringSync();

      expect(
        localAdapter,
        contains(
          'PHASE3I-J2F4: conservative productive local adapter binding',
        ),
      );
      expect(
        localAdapter,
        contains('ClinicalTreatmentPresentationAdapter'),
      );
      for (final source in <String>[structured, renderer, provider]) {
        expect(
          source,
          isNot(contains('ClinicalTreatmentPresentationAdapter')),
        );
      }
    });

    test('does not access canonical drug identity or dose validation', () {
      final source = File(
        'lib/services/ai_pipeline/clinical_treatment_presentation_adapter.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('drugDocumentId')));
      expect(source, isNot(contains('evidenceVersion')));
      expect(source, isNot(contains('validationStatus')));
      expect(source, isNot(contains('PlantaoDeterministicDrugValidator')));
      expect(source, isNot(contains('_dosePattern')));
    });

    test('J2D1 and J2F1 remain present; J2D2 remains absent', () {
      final screen = File('lib/screens/ai_screen.dart').readAsStringSync();
      final contract = File(
        'lib/models/clinical_treatment_presentation.dart',
      ).readAsStringSync();
      final renderer = File(
        'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
      ).readAsStringSync();

      expect(
        screen,
        contains('PHASE3I-J2D1: bind canonical user case anchor'),
      );
      expect(
        contract,
        contains('PHASE3I-J2F1: productive treatment presentation contract'),
      );
      expect(
        renderer,
        isNot(
          contains('PHASE3I-J2D2: legacy treatment relation policy'),
        ),
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_treatment_presentation.dart';
import 'package:medcases/services/ai_pipeline/clinical_treatment_presentation_adapter.dart';

void main() {
  group('PHASE3I-J2F4 V2 explicit section boundaries', () {
    test('non-treatment heading ends concomitant relation', () {
      final result = ClinicalTreatmentPresentationAdapter.fromExplicitText(
        '''
Tratamento inicial combinado:
- AAS 300 mg VO
- Clopidogrel 300 mg VO

Conduta imediata:
- Monitorizar continuamente
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

    test('markdown heading ends conditional relation', () {
      final result = ClinicalTreatmentPresentationAdapter.fromExplicitText(
        '''
Uso condicional:
- Nitrato 0,4 mg SL

**Monitorização:**
- Pressão arterial contínua
''',
      );

      expect(
        result
            .itemsFor(ClinicalTreatmentRelation.conditional)
            .map((item) => item.text),
        orderedEquals(<String>['Nitrato 0,4 mg SL']),
      );
    });

    test('bullet content containing colon stays inside relation', () {
      final result = ClinicalTreatmentPresentationAdapter.fromExplicitText(
        '''
Tratamento combinado:
- Meta: manter saturação acima de 94%
- AAS 300 mg VO
''',
      );

      expect(
        result
            .itemsFor(ClinicalTreatmentRelation.concomitant)
            .map((item) => item.text),
        orderedEquals(<String>[
          'Meta: manter saturação acima de 94%',
          'AAS 300 mg VO',
        ]),
      );
    });

    test('bold markdown heading is boundary while star bullet stays content',
        () {
      final result = ClinicalTreatmentPresentationAdapter.fromExplicitText(
        '''
Uso condicional:
* Nitrato 0,4 mg SL

**Monitorização:**
* Pressão arterial contínua
''',
      );

      expect(
        result
            .itemsFor(ClinicalTreatmentRelation.conditional)
            .map((item) => item.text),
        orderedEquals(<String>['Nitrato 0,4 mg SL']),
      );
    });

    test('unknown heading without active relation stays ignored', () {
      final result = ClinicalTreatmentPresentationAdapter.fromExplicitText(
        '''
Conduta imediata:
- Monitorizar continuamente
''',
      );

      expect(result.items, isEmpty);
      expect(result.safetyFlags, isEmpty);
    });
  });
}

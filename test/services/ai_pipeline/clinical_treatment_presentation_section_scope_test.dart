import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_treatment_presentation.dart';
import 'package:medcases/services/ai_pipeline/clinical_treatment_presentation_adapter.dart';

void main() {
  group('PHASE3I-J2F10C-E section-scoped pending relation', () {
    test('bullet relation does not capture immediate-section medications', () {
      const text = '''
Conduta imediata:
• AAS 300 mg VO mastigar
• TRATAMENTO INICIAL COMBINADO

Tratamento farmacológico:
• AAS 300 mg VO [antiagregante plaquetário]
• Clopidogrel 300 mg VO [antiagregante plaquetário]

Pontos-chave:
• Monitorar sinais vitais
''';

      final presentation =
          ClinicalTreatmentPresentationAdapter.fromExplicitText(text);

      expect(presentation.items, hasLength(2));
      expect(
        presentation.items.map((item) => item.relation).toSet(),
        {ClinicalTreatmentRelation.concomitant},
      );
      expect(
        presentation.items.map((item) => item.text).toList(),
        [
          'AAS 300 mg VO [antiagregante plaquetário]',
          'Clopidogrel 300 mg VO [antiagregante plaquetário]',
        ],
      );
    });

    test('standalone heading still activates relation immediately', () {
      const text = '''
Tratamento inicial combinado:
• AAS 300 mg VO
• Clopidogrel 300 mg VO
''';

      final presentation =
          ClinicalTreatmentPresentationAdapter.fromExplicitText(text);

      expect(presentation.items, hasLength(2));
      expect(
        presentation.items.every(
          (item) => item.relation == ClinicalTreatmentRelation.concomitant,
        ),
        isTrue,
      );
    });

    test('pending relation fails closed without pharmacologic boundary', () {
      const text = '''
Conduta imediata:
• TRATAMENTO INICIAL COMBINADO
• AAS 300 mg VO
• Clopidogrel 300 mg VO

Pontos-chave:
• Monitorar
''';

      final presentation =
          ClinicalTreatmentPresentationAdapter.fromExplicitText(text);

      expect(presentation.items, isEmpty);
    });

    test('first and second line semantics remain outside this adapter', () {
      const text = '''
1ª linha:
• Ceftriaxona 2 g IV

2ª linha:
• Piperacilina-tazobactam 4,5 g IV
''';

      final presentation =
          ClinicalTreatmentPresentationAdapter.fromExplicitText(text);

      expect(presentation.items, isEmpty);
    });
  });
}

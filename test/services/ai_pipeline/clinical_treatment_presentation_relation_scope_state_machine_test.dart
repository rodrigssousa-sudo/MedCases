import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_treatment_presentation.dart';
import 'package:medcases/services/ai_pipeline/clinical_treatment_presentation_adapter.dart';

void main() {
  group('PHASE3I-J2F10C-H explicit relation scope state machine', () {
    test('top heading skips one immediate section and binds pharmacologic', () {
      const text = """
TRATAMENTO INICIAL COMBINADO

Conduta imediata:
• AAS 300 mg VO mastigar
• Oxigênio se necessário

Tratamento farmacológico:
• AAS 300 mg VO [antiagregante plaquetário]
• Clopidogrel 300 mg VO [antiagregante plaquetário]

Pontos-chave:
• Monitorar sinais vitais
""";

      final presentation =
          ClinicalTreatmentPresentationAdapter.fromExplicitText(text);

      expect(presentation.items, hasLength(2));
      expect(
        presentation.items.map((item) => item.text).toList(),
        [
          'AAS 300 mg VO [antiagregante plaquetário]',
          'Clopidogrel 300 mg VO [antiagregante plaquetário]',
        ],
      );
      expect(
        presentation.items.every(
          (item) => item.relation == ClinicalTreatmentRelation.concomitant,
        ),
        isTrue,
      );
    });

    test('bullet relation inside section ignores following items until pharma',
        () {
      const text = """
Conduta imediata:
• TRATAMENTO INICIAL COMBINADO
• AAS 300 mg VO
• Clopidogrel 300 mg VO

Pontos-chave:
• Monitorar
""";

      final presentation =
          ClinicalTreatmentPresentationAdapter.fromExplicitText(text);

      expect(presentation.items, isEmpty);
    });

    test('standalone heading with direct items remains valid', () {
      const text = """
Tratamento inicial combinado:
• AAS 300 mg VO
• Clopidogrel 300 mg VO
""";

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

    test('pending heading expires after two non-treatment boundaries', () {
      const text = """
Tratamento inicial combinado:

Conduta imediata:
• AAS 300 mg VO

Pontos-chave:
• Monitorar sinais vitais

Tratamento farmacológico:
• Clopidogrel 300 mg VO
""";

      final presentation =
          ClinicalTreatmentPresentationAdapter.fromExplicitText(text);

      expect(presentation.items, isEmpty);
    });

    test('first and second line remain outside typed promotion', () {
      const text = """
1ª linha:
• Amoxicilina 1 g VO

2ª linha:
• Azitromicina 500 mg VO
""";

      final presentation =
          ClinicalTreatmentPresentationAdapter.fromExplicitText(text);

      expect(presentation.items, isEmpty);
    });
  });
}

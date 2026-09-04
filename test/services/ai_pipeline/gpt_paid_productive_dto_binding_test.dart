import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_structured_output.dart';
import 'package:medcases/services/ai_pipeline/plantao_local_clinical_output_adapter.dart';

void main() {
  group('PHASE3I-J2F10C-B2-R2 canonical-fixture paid DTO binding', () {
    test('binds local DTO only for paid Plantao when backend DTO is null', () {
      final provider =
          File('lib/providers/app_provider.dart').readAsStringSync();

      expect(
        provider,
        contains(
          'final ClinicalStructuredOutput? productiveClinicalOutput =',
        ),
      );
      expect(
        provider,
        contains(
          'clinicalOutput ??\n'
          '        (!longResponse\n'
          '            ? PlantaoLocalClinicalOutputAdapter.fromValidatedText(',
        ),
      );
      expect(provider, contains('validatedOutput,'));
      expect(
        provider,
        contains(
          'safeOutput == validatedOutput ? productiveClinicalOutput : null',
        ),
      );
      expect(provider, contains('[STRUCTURED_PAID][BOUND]'));
      expect(
        provider,
        contains(
          'source=\${clinicalOutput != null ? "backend" : "local_adapter"}',
        ),
      );
      expect(provider,
          isNot(contains('safeClinicalOutput?.treatmentPresentation')));
      expect(
        provider,
        isNot(contains('productiveClinicalOutput?.treatmentPresentation')),
      );
      expect(provider, isNot(contains('treatmentItems=')));
    });

    test('canonical concomitant fixture creates the typed contract', () {
      const text = """
🟥 Síndrome coronariana aguda

Tratamento inicial combinado:
- **AAS** 300 mg VO
- **Clopidogrel** 300 mg VO

Alerta clínico:
- Monitorar hipotensão

HARD STOP:
- Não administrar nitrato com PAS menor de 90 mmHg
""";

      final ClinicalStructuredOutput? output =
          PlantaoLocalClinicalOutputAdapter.fromValidatedText(text);

      expect(output, isNotNull);
      expect(output!.prescricao, hasLength(2));
      expect(output.primeiraLinha, isEmpty);
      expect(output.segundaLinha, isEmpty);
      expect(output.treatmentPresentation.items, hasLength(2));
      expect(output.hardStops, hasLength(1));
    });

    test('first and second line remain explicit legacy fallback data', () {
      const text = """
🟥 PNEUMONIA COMUNITÁRIA

1ª linha:
• Amoxicilina 1 g VO 8/8h

2ª linha:
• Azitromicina 500 mg VO 1x/dia

HARD STOP:
• Alergia grave a beta-lactâmicos
""";

      final output = PlantaoLocalClinicalOutputAdapter.fromValidatedText(text);

      expect(output, isNotNull);
      expect(output!.primeiraLinha, isNotEmpty);
      expect(output.segundaLinha, isNotEmpty);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/clinical_reference_resolver.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';
import 'package:medcases/services/ai_pipeline/plantao_clinical_response_consistency_guard.dart';

void main() {
  group('Diverticulitis physical identity language reference closure', () {
    test('Spanish app language wins over Portuguese user wording', () {
      const raw = """
🟥 DIVERTICULITIS AGUDA NO COMPLICADA RECURRENTE
🚨 Conducta inmediata:
* Solicitar TC abdomen/pelvis para confirmar y valorar gravedad.
""";

      final out = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: 'diverticulite aguda recorrente não complicada',
        assistantOutput: raw,
        languageCode: 'es',
      );

      expect(
        out,
        contains('TC de abdomen/pelvis: indicada en la primera presentación'),
      );
      expect(
        out,
        contains('En recurrencia típica ya documentada, no es automática'),
      );
      expect(out, isNot(contains('TC de abdome/pelve')));
      expect(out, isNot(contains('primeira apresentação')));
    });

    test('uncomplicated recurrent phenotype resolves acute protocol', () {
      final result = ClinicalReferenceResolver.resolve(
        userText: 'diverticulite aguda recorrente não complicada',
        aiText: """
🟥 DIVERTICULITIS AGUDA NO COMPLICADA RECURRENTE
🚨 Conducta inmediata:
* Manejo ambulatorio si estable.
""",
        lang: 'es',
      );

      expect(result.sourceType, 'clinical_protocol');
      expect(result.protocolId, 'diverticulitis_aguda_015');
      expect(result.protocolId, isNot('diverticulitis_complicada_2026'));
    });

    test('explicit complicated phenotype still resolves complicated protocol', () {
      final result = ClinicalReferenceResolver.resolve(
        userText: 'diverticulitis aguda complicada con absceso',
        aiText: """
🟥 DIVERTICULITIS AGUDA COMPLICADA
🚨 Conducta inmediata:
* Evaluar absceso y control de foco.
""",
        lang: 'es',
      );

      expect(result.sourceType, 'clinical_protocol');
      expect(result.protocolId, 'diverticulitis_complicada_2026');
    });

    testWidgets('cross-language explicit topic preserves provider title', (tester) async {
      const raw = """
🟥 DIVERTICULITIS AGUDA NO COMPLICADA RECURRENTE
🚨 Conducta inmediata:
* Manejo ambulatorio si estable.
🔑 Puntos clave:
* Seguimiento clínico.
""";

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuardiaClinicalResponseView(
              rawText: raw,
              dark: true,
              languageCode: 'es',
              userText: 'diverticulite aguda recorrente não complicada',
              userInitiatedByAction: false,
              typedTreatmentVisualEnabled: false,
              onCopy: () {},
            ),
          ),
        ),
      );

      expect(
        find.text('DIVERTICULITIS AGUDA NO COMPLICADA RECURRENTE'),
        findsOneWidget,
      );
      expect(find.text('Orientación clínica'), findsNothing);
      expect(find.text('Conducta inmediata'), findsOneWidget);
      expect(find.text('Evaluación inicial'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nonspecific symptom still demotes inferred diagnosis', (tester) async {
      const raw = """
🟥 DIVERTICULITIS AGUDA
🚨 Conducta inmediata:
* Evaluar estabilidad.
""";

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuardiaClinicalResponseView(
              rawText: raw,
              dark: true,
              languageCode: 'es',
              userText: 'dolor abdominal',
              userInitiatedByAction: false,
              typedTreatmentVisualEnabled: false,
              onCopy: () {},
            ),
          ),
        ),
      );

      expect(find.text('Orientación clínica'), findsOneWidget);
      expect(find.text('DIVERTICULITIS AGUDA'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

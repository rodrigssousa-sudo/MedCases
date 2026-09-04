import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_structured_output.dart';
import 'package:medcases/screens/ai/widgets/clinical_reference_resolver.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';
import 'package:medcases/services/ai_pipeline/plantao_local_clinical_output_adapter.dart';

void main() {
  group('Plantao presentation identity section integrity resolver V1-B-R6', () {
    testWidgets(
      'long physical IAMCEST question preserves known disease title',
      (tester) async {
        const raw = """
🟥 INFARTO AGUDO DE MIOCARDIO CON ELEVACIÓN DEL ST (IAMCEST)
🚨 Conducta inmediata:
* 1. MONITORIZACIÓN: ECG continuo, SpO2 y PA cada 15 min
* 2. O2 si SpO2 <90%: mascarilla 5–10 L/min
* 3. Acceso venoso y análisis de laboratorio inmediato
💊 Tratamiento farmacológico:
* AAS 300 mg VO masticar
* Ticagrelor 180 mg VO
🔑 Puntos clave:
* Reperfusión urgente.
🚩 RED FLAGS:
* Inestabilidad hemodinámica.
""";

        const user =
            'Paciente de 62 años con IAMCEST confirmado, dolor '
            'torácico persistente y elevación del ST en V2-V5. PA 132/78 '
            'mmHg, FC 96 lpm, SpO2 96% al aire ambiente. Troponina elevada. '
            'Sin shock, sin edema agudo de pulmón y sin paro cardíaco. '
            '¿Analiza el caso e indica la conducta inicial?';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: GuardiaClinicalResponseView(
                  rawText: raw,
                  userText: user,
                  dark: true,
                  languageCode: 'es',
                  typedTreatmentVisualEnabled: false,
                  onCopy: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Orientación clínica'), findsNothing);
        expect(
          find.textContaining('INFARTO AGUDO DE MIOCARDIO', findRichText: true),
          findsWidgets,
        );
        expect(find.text('Conducta inmediata'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'classification follow-up uses classification title, not generic orientation',
      (tester) async {
        const raw = """
🟥 CLASIFICACIÓN DEL PACIENTE
🔑 Puntos clave:
* Clasificación del paciente: IAMCEST.
* Gravedad: Killip I — sin congestión.
📌 Clasificación final: IAMCEST, Killip I.
""";

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GuardiaClinicalResponseView(
                rawText: raw,
                userText: '¿Y cuál es la clasificación?',
                dark: true,
                languageCode: 'es',
                typedTreatmentVisualEnabled: false,
                onCopy: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Orientación clínica'), findsNothing);
        expect(
          find.textContaining('Clasificación', findRichText: true),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
      },
    );

    test('adapter keeps supportive O2 outside pharmacologic prescriptions', () {
      const raw = """
🟥 IAMCEST
🚨 Conducta inmediata:
* 1. MONITORIZACIÓN: ECG continuo, SpO2 y PA cada 15 min
* 2. O2 si SpO2 <90%: mascarilla 5–10 L/min
* 3. Acceso venoso y análisis inmediato
💊 Tratamiento farmacológico:
* AAS 300 mg VO masticar
* Ticagrelor 180 mg VO
""";

      final output = PlantaoLocalClinicalOutputAdapter.fromValidatedText(raw);

      expect(output, isNotNull);
      expect(
        output!.prescricao.any(
          (item) =>
              item.farmaco.toLowerCase().contains('o2') ||
              item.farmaco.toLowerCase().contains('oxigen'),
        ),
        isFalse,
      );
      expect(
        output.condutaImediataItens.any(
          (item) => item.toLowerCase().contains('o2 si spo2'),
        ),
        isTrue,
      );
      expect(output.prescricao.any((item) => item.farmaco == 'AAS'), isTrue);
      expect(
        output.prescricao.any((item) => item.farmaco == 'Ticagrelor'),
        isTrue,
      );
    });

    testWidgets('equivalent HNF continuous regimens render once', (
      tester,
    ) async {
      const raw = """
🟥 IAMCEST
🚨 Conducta inmediata:
* Monitorización continua.
💊 Tratamiento farmacológico:
* HNF 60–70 UI/kg IV bolo (máx. 5000 UI)
* Infusión continua HNF 12–15 UI/kg/h — mantener anticoagulación
""";

      final output = ClinicalStructuredOutput(
        diagnosticoHeuristico: 'IAMCEST',
        condutaImediata: 'Monitorización continua.',
        prescricao: const <ClinicalPrescriptionItem>[
          ClinicalPrescriptionItem(
            farmaco: 'HNF',
            posologia: '60–70 UI/kg IV bolo (máx. 5000 UI)',
          ),
          ClinicalPrescriptionItem(
            farmaco: 'Continua HNF',
            posologia: '12–15 UI/kg/h — mantener anticoagulación',
          ),
          ClinicalPrescriptionItem(
            farmaco: 'Infusión continua HNF',
            posologia: '12–15 UI/kg/h — mantener anticoagulación',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GuardiaClinicalResponseView(
                rawText: raw,
                userText:
                    'Paciente con IAMCEST confirmado. Indica tratamiento.',
                output: output,
                dark: true,
                languageCode: 'es',
                typedTreatmentVisualEnabled: false,
                onCopy: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('12–15 UI/kg/h', findRichText: true),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    test('explicit IAMCEST resolves iam_supra when congestion is negated', () {
      final result = ClinicalReferenceResolver.resolve(
        userText:
            'Paciente con IAMCEST confirmado, elevación persistente del ST '
            'en V2-V5, sin edema agudo de pulmón y sin shock.',
        aiText: """
INFARTO AGUDO DE MIOCARDIO CON ELEVACIÓN DEL ST (IAMCEST)
Conducta inmediata y reperfusión urgente.
""",
        lang: 'es',
      );

      expect(result.protocolId, 'iam_supra');
      expect(result.protocolId, isNot('sindrome_coronariana_sem_st'));
      expect(result.protocolId, isNot('iam_congestao'));
    });

    test('explicit NSTE-ACS remains on NSTE protocol', () {
      final result = ClinicalReferenceResolver.resolve(
        userText:
            'Paciente con IAMSEST confirmado, troponina elevada y sin '
            'elevación persistente del ST.',
        aiText: """
SÍNDROME CORONARIO AGUDO SIN ELEVACIÓN DEL ST (SCASEST)
Conducta inicial.
""",
        lang: 'es',
      );

      expect(result.protocolId, 'sindrome_coronariana_sem_st');
    });

    test('management RAG telemetry is intent-specific', () {
      final app = File('lib/providers/app_provider.dart').readAsStringSync();

      expect(
        app,
        contains('PLANTAO_CONTEXT_RAG_INTENT_TELEMETRY_EXCLUSIVITY_V1'),
      );
      expect(app, contains('contextRagTelemetryTag'));
      expect(
        app,
        contains('PLANTAO_CLASSIFICATION_CONTEXTUAL_RAG_SHADOW_PROPAGATION_V2'),
      );
    });

    test('frozen Thread and AI contracts remain present', () {
      final ai = File('lib/services/ai_service.dart').readAsStringSync();
      final thread = File(
        'lib/services/clinical_thread_manager.dart',
      ).readAsStringSync();

      expect(ai, contains('PLANTAO_CLASSIFICATION_ACTIVE_CONTRACT_V2'));
      expect(ai, contains('PLANTAO_FULL_MANAGEMENT_PHARMA_ACTIVE_V2'));
      expect(thread, contains('PLANTAO_EXPLICIT_CASE_BOUNDARY_PRECEDENCE_V1'));
      expect(thread, contains('PLANTAO_DEPENDENT_MANAGEMENT_FOLLOWUP_V1'));
    });
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_structured_output.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';
import 'package:medcases/services/clinical_thread_manager.dart';

void main() {
  group('Plantao dependent management context + pharma surface V1-B-R5', () {
    test('physical IAM management follow-up remains in active thread', () {
      final manager = ClinicalThreadManager();

      manager.evaluate(
        currentUserText:
            'Paciente de 62 años con IAMCEST confirmado, dolor torácico '
            'persistente y elevación del ST en V2-V5. PA 132/78 mmHg, '
            'FC 96 lpm, SpO2 96% al aire ambiente. Troponina elevada. '
            'Sin shock, sin edema agudo de pulmón y sin paro cardíaco.',
        isPlantaoMode: true,
      );

      final classification = manager.evaluate(
        currentUserText: '¿Y cuál es la clasificación?',
        isPlantaoMode: true,
      );
      expect(classification.action, ThreadAction.continueThread);

      final treatment = manager.evaluate(
        currentUserText:
            '¿Y qué tratamiento farmacológico completo indicarías ahora?',
        isPlantaoMode: true,
      );

      expect(treatment.action, ThreadAction.continueThread);
    });

    test('different explicit pathology still starts a new thread', () {
      final manager = ClinicalThreadManager();

      manager.evaluate(
        currentUserText:
            'Paciente con IAMCEST confirmado y elevación persistente del ST.',
        isPlantaoMode: true,
      );

      final next = manager.evaluate(
        currentUserText:
            '¿Y qué tratamiento farmacológico indicarías para diabetes mellitus?',
        isPlantaoMode: true,
      );

      expect(next.action, ThreadAction.newThread);
    });

    test('explicit new patient remains an absolute boundary', () {
      final manager = ClinicalThreadManager();

      manager.evaluate(
        currentUserText:
            'Paciente con IAMCEST confirmado y elevación persistente del ST.',
        isPlantaoMode: true,
      );

      final next = manager.evaluate(
        currentUserText:
            'Nuevo paciente con IAMCEST confirmado. ¿Qué tratamiento indicarías ahora?',
        isPlantaoMode: true,
      );

      expect(next.action, ThreadAction.newThread);
    });

    test('Portuguese explicit new patient also remains an absolute boundary', () {
      final manager = ClinicalThreadManager();

      manager.evaluate(
        currentUserText:
            'Paciente com IAMCEST confirmado e supra persistente de ST.',
        isPlantaoMode: true,
      );

      final next = manager.evaluate(
        currentUserText:
            'Novo paciente com IAMCEST confirmado. Qual tratamento indicaria agora?',
        isPlantaoMode: true,
      );

      expect(next.action, ThreadAction.newThread);
    });

    test('English explicit new patient remains an absolute boundary', () {
      final manager = ClinicalThreadManager();

      manager.evaluate(
        currentUserText:
            'Patient with confirmed STEMI and persistent ST elevation.',
        isPlantaoMode: true,
      );

      final next = manager.evaluate(
        currentUserText:
            'New patient with confirmed STEMI. What treatment would you give now?',
        isPlantaoMode: true,
      );

      expect(next.action, ThreadAction.newThread);
    });

    test(
      'AppProvider reuses active-topic protocol RAG for dependent management',
      () {
        final source = File(
          'lib/providers/app_provider.dart',
        ).readAsStringSync();

        expect(source, contains('PLANTAO_DEPENDENT_MANAGEMENT_CONTEXT_RAG_V1'));
        expect(source, contains('_isProtocolDependentManagementRequest'));
        expect(source, contains('[PLANTAO_MANAGEMENT_CONTEXT_RAG]'));
        expect(
          source,
          contains("_threadManager.activeTopic.replaceAll('_', ' ')"),
        );
        expect(source, contains('protocols.add(contextualProtocol);'));
        expect(
          source,
          contains(
            'if (isDependentManagementRequest && !isClassificationRequest)',
          ),
        );
      },
    );

    test(
      'classification V2 and R9 management owners remain frozen in source',
      () {
        final ai = File('lib/services/ai_service.dart').readAsStringSync();
        final app = File('lib/providers/app_provider.dart').readAsStringSync();

        expect(ai, contains('PLANTAO_CLASSIFICATION_ACTIVE_CONTRACT_V2'));
        expect(ai, contains('PLANTAO_FULL_MANAGEMENT_PHARMA_ACTIVE_V2'));
        expect(
          app,
          contains(
            'PLANTAO_CLASSIFICATION_CONTEXTUAL_RAG_SHADOW_PROPAGATION_V2',
          ),
        );
      },
    );

    testWidgets(
      'confirmed IAM with DTO prescriptions shows pharmacologic section even '
      'when raw text has no pharmacologic heading',
      (tester) async {
        const raw = '''
🟥 INFARTO AGUDO DE MIOCARDIO CON AUMENTO DEL ST

🚨 Conducta inmediata:
* Monitorización continua: ECG, SpO2, PA cada 15 min.
* Oxígeno solo si SpO2 < 90%.
* AAS 300 mg VO + Ticagrelor 180 mg VO.

🔑 Puntos clave:
* Valorar revascularización urgente.

🚩 RED FLAGS:
* Inestabilidad hemodinámica o deterioro progresivo.

📌 Siguiente paso: evaluar posibilidad de cateterismo cardíaco urgente.
''';

        final output = ClinicalStructuredOutput(
          diagnosticoHeuristico: 'IAMCEST',
          condutaImediata:
              'Monitorización continua y estrategia de reperfusión.',
          prescricao: <ClinicalPrescriptionItem>[
            ClinicalPrescriptionItem(farmaco: 'AAS', posologia: '300 mg VO'),
            ClinicalPrescriptionItem(
              farmaco: 'Ticagrelor',
              posologia: '180 mg VO',
            ),
          ],
          pontosChave: <String>['Valorar revascularización urgente.'],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: GuardiaClinicalResponseView(
                  rawText: raw,
                  userText:
                      'Paciente de 62 años con IAMCEST confirmado, dolor '
                      'torácico persistente y elevación del ST en V2-V5.',
                  output: output,
                  dark: false,
                  languageCode: 'es',
                  onCopy: () {},
                  isStreaming: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey('guardia_pharmacologic_section')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Tratamiento farmacológico', findRichText: true),
          findsWidgets,
        );
        expect(find.textContaining('AAS', findRichText: true), findsWidgets);
        expect(
          find.textContaining('300 mg VO', findRichText: true),
          findsWidgets,
        );
        expect(
          find.textContaining('Ticagrelor', findRichText: true),
          findsWidgets,
        );
        expect(
          find.textContaining('180 mg VO', findRichText: true),
          findsWidgets,
        );
      },
    );

    test('renderer keeps differential hard gate and no-emoji owner', () {
      final source = File(
        'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
      ).readAsStringSync();

      expect(source, contains('PLANTAO_CONFIRMED_CASE_RX_SURFACE_V1'));
      expect(source, contains('_guardiaUserTextHasExplicitConfirmedDiagnosis'));
      expect(source, contains('!content.isDifferential'));
      expect(source, contains('GuardiaNoEmojiPresentation.clean'));
    });
  });
}

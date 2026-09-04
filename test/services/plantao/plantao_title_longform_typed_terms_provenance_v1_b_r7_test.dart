import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';

void main() {
  group('Plantao title long-form + typed-terms provenance V1-B-R7', () {
    const initialUser =
        'Paciente de 62 años con IAMCEST confirmado, dolor '
        'torácico persistente y elevación del ST en V2-V5. PA 132/78 '
        'mmHg, FC 96 lpm, SpO2 96% al aire ambiente. Troponina elevada. '
        'Sin shock, sin edema agudo de pulmón y sin paro cardíaco. '
        'Analiza el caso e indica la conducta inicial.';

    testWidgets(
      'exact physical RAW without IAMCEST acronym keeps STEMI disease title',
      (tester) async {
        const raw = """
🟥 INFARTO AGUDO DE MIOCARDIO CON SEGMENTO ST Elevado
🚨 Conducta inmediata:
* 1. MONITORIZACIÓN: ECG continuo, SpO2, PA cada 15 min.
* 2. O2 si SpO2 <90%: mascarilla 5–10 L/min.
💊 Tratamiento farmacológico:
* AAS 300 mg VO masticar
* Ticagrelor 180 mg VO
* HNF 60–70 UI/kg IV bolo
🔑 Puntos clave:
* Preparar cateterismo urgente.
""";

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: GuardiaClinicalResponseView(
                  rawText: raw,
                  userText: initialUser,
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

        expect(find.text('Conducta clínica'), findsNothing);
        expect(find.text('Orientación clínica'), findsNothing);
        expect(
          find.textContaining(
            'INFARTO AGUDO DE MIOCARDIO CON ELEVACIÓN DEL ST (IAMCEST)',
            findRichText: true,
          ),
          findsWidgets,
        );
        expect(find.text('Conducta inmediata'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'dependent pharmacology follow-up composes task plus known disease identity',
      (tester) async {
        const raw = """
🟥 INFARTO AGUDO DE MIOCARDIO CON SEGMENTO ST Elevado
🚨 Conducta inmediata:
* MONITORIZACIÓN: ECG continuo, SpO2, PA cada 15 min.
💊 Tratamiento farmacológico:
* AAS 300 mg VO masticar
* Ticagrelor 180 mg VO
* HNF 60–70 UI/kg IV bolo
🔑 Puntos clave:
* Preparar cateterismo urgente.
""";

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: GuardiaClinicalResponseView(
                  rawText: raw,
                  userText:
                      '¿Y qué tratamiento farmacológico completo indicarías ahora?',
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

        expect(find.text('Conducta clínica'), findsNothing);
        expect(find.text('Orientación clínica'), findsNothing);
        expect(
          find.textContaining(
            'Tratamiento farmacológico — INFARTO AGUDO DE MIOCARDIO',
            findRichText: true,
          ),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
      },
    );

    test(
      'source uses direct finalized typed terms and preserves fail-closed NSTE guard',
      () {
        final app = File('lib/providers/app_provider.dart').readAsStringSync();
        final guardia = File(
          'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
        ).readAsStringSync();

        expect(
          app,
          contains(
            'PLANTAO_FINALIZED_VISIBLE_MEDICATION_TYPED_TERMS_FALLBACK_V2',
          ),
        );
        expect(
          app,
          contains(
            '_plantaoDrugEvidenceRequestObserver.adapter.retrieveTypedTerms(',
          ),
        );
        expect(app, contains('terms: finalizedMedicationIdentities'));
        expect(app, contains('strategy=typed_terms'));
        expect(
          app,
          contains('finalized_visible_medication_typed_terms_fallback'),
        );

        final marker = app.indexOf(
          'PLANTAO_FINALIZED_VISIBLE_MEDICATION_EVIDENCE_FALLBACK_V1',
        );
        expect(marker, greaterThanOrEqualTo(0));
        final tail = app.substring(
          marker,
          (marker + 10000).clamp(0, app.length),
        );
        expect(tail, isNot(contains('shadowOnlyIdentityQuery')));
        expect(tail, isNot(contains('.observeRequest(')));

        expect(
          guardia,
          contains('PLANTAO_PRESENTATION_STEMI_LONG_FORM_EQUIVALENCE_V2'),
        );
        expect(guardia, contains('con segmento st elevado'));
        expect(guardia, contains('sin elevacion del st'));
        expect(guardia, contains('without st elevation'));
      },
    );

    test('frozen safety owners remain represented by their prior markers', () {
      final guardia = File(
        'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
      ).readAsStringSync();
      final app = File('lib/providers/app_provider.dart').readAsStringSync();
      final adapter = File(
        'lib/services/ai_pipeline/plantao_local_clinical_output_adapter.dart',
      ).readAsStringSync();
      final resolver = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      expect(
        guardia,
        contains('PLANTAO_PRESENTATION_IDENTITY_LONG_FORM_TASK_TITLE_V1'),
      );
      expect(guardia, contains('PLANTAO_SEMANTIC_MEDICATION_DEDUPE_V1'));
      expect(adapter, contains('PLANTAO_SUPPORTIVE_OXYGEN_NOT_DRUG_RX_V1'));
      expect(
        resolver,
        contains('PLANTAO_EXPLICIT_CORONARY_PHENOTYPE_PRECEDENCE_V1'),
      );
      expect(
        app,
        contains('PLANTAO_CONTEXT_RAG_INTENT_TELEMETRY_EXCLUSIVITY_V1'),
      );
    });
  });
}

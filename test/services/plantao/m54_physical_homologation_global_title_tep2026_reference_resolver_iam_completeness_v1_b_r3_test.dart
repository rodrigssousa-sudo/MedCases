import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/clinical_reference_resolver.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';
import 'package:medcases/services/ai_service.dart';
import 'package:medcases/services/tep_2026_plantao_response_guard.dart';

Finder _visibleTextContaining(String needle) {
  return find.byWidgetPredicate((widget) {
    if (widget is Text) {
      final value = widget.data ?? widget.textSpan?.toPlainText() ?? '';
      return value.contains(needle);
    }
    if (widget is RichText) {
      return widget.text.toPlainText().contains(needle);
    }
    return false;
  });
}

void main() {
  group('M54 physical homologation corrective macrobuild R6', () {
    testWidgets('ANAFILAXIA raw disease identity cannot collapse to Conducta clínica', (tester) async {
      const raw = '''
🟥 ANAFILAXIA
🚨 Conducta inmediata:
* ADRENALINA IM inmediatamente como primera línea.
🔑 Puntos clave:
* Reevaluar respuesta y monitorizar.
🚩 RED FLAGS:
* Shock persistente o amenaza de vía aérea.
''';
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: GuardiaClinicalResponseView(
        rawText: raw,
        userText: 'Mujer de 34 años tras maní con urticaria, edema labial, sibilancias e hipotensión. ¿Diagnóstico y conducta?',
        userInitiatedByAction: false,
        dark: true,
        languageCode: 'es',
        typedTreatmentVisualEnabled: false,
        onCopy: () {},
      ))));
      await tester.pump();
      expect(find.text('ANAFILAXIA'), findsOneWidget);
      expect(find.text('Conducta clínica'), findsNothing);
      expect(find.text('Orientación clínica'), findsNothing);
      expect(find.text('Conducta inmediata'), findsOneWidget);
      expect(_visibleTextContaining('ADRENALINA IM'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    test('renderer source overrides only forbidden generic top-level titles', () {
      final source = File('lib/screens/ai/widgets/guardia_clinical_response_view.dart').readAsStringSync();
      expect(source, contains('M54_PHYSICAL_GLOBAL_DISEASE_TITLE_CONTRACT_V2'));
      expect(source, contains('_guardiaM54RawConcreteDiseaseTitle'));
      expect(source, contains('_guardiaM54GenericTopLevelTitle'));
      expect(source, contains('m54GenericBaseTitle &&'));
      expect(source, contains(': baseTitleProjection;'));
    });

    test('TEP exact physical case materializes AHA/ACC 2026 C3R', () {
      const input =
          'Paciente de 68 años con embolia pulmonar aguda confirmada por angio-TC. '
          'Presenta disnea y dolor torácico. PA 118/72 mmHg, FC 118 lpm, FR 32 rpm, '
          'SpO2 88% al aire ambiente. No presentó hipotensión ni paro. '
          'La angio-TC muestra relación VD/VI de 1,2 y la troponina está elevada. '
          'Según la clasificación AHA/ACC 2026 del TEP, ¿en qué categoría y subcategoría está este paciente? '
          '¿Tiene modificador R? Explica por qué y cuál es la conducta correspondiente. '
          'No utilices Wells como clasificación de gravedad después de que el TEP ya está confirmado.';
      const unsafeRaw = '''
🟥 CLASIFICACIÓN DEL PACIENTE
🔑 Puntos clave:
* TEP de alto riesgo (progresivo).
* Clase II (intermedia/alta), relación VD/VI > 1,5.
''';
      final resolution = Tep2026PlantaoResponseGuard.resolve(input);
      expect(resolution, isNotNull);
      expect(resolution!.category, 'C3');
      expect(resolution.respiratoryModifier, isTrue);
      expect(resolution.rvLvRatio, 1.2);
      final out = Tep2026PlantaoResponseGuard.materialize(userInput: input, assistantOutput: unsafeRaw, languageCode: 'es');
      expect(out, contains('C3R'));
      expect(out, contains('AHA/ACC 2026'));
      final guardSource = File('lib/services/tep_2026_plantao_response_guard.dart').readAsStringSync();
      expect(guardSource, contains('M54_TEP_ES_ENTRY_CANONICAL_ALIAS_V1'));
      expect(guardSource, contains("RegExp(r'\\bembolia\\s+pulmonar\\b', caseSensitive: false)"));
      expect(guardSource, contains('return m54DirectConfirmation || (pe && confirmed);'));
      expect(out, contains('| Relación VD/VI | **1,2** |'));
      expect(out.toLowerCase(), isNot(contains('wells')));
      expect(out, isNot(contains('Clase II')));
      expect(out, isNot(contains('intermedia/alta')));
      expect(out, isNot(contains('progresivo')));
      expect(out, isNot(contains('> 1,5')));
      expect(out.toLowerCase(), isNot(contains('massive')));
      expect(out.toLowerCase(), isNot(contains('submassive')));
    });

    test('TEP same objective facts render C3R in Portuguese too', () {
      const input =
          'Paciente de 68 anos com tromboembolismo pulmonar agudo confirmado por angio-TC. '
          'PA 118/72 mmHg, FC 118 bpm, FR 32 irpm, SpO2 88% em ar ambiente. '
          'A angio-TC mostra relação VD/VI 1,2 e troponina elevada. '
          'Sem hipotensão e sem parada cardíaca. Classifique segundo AHA/ACC 2026 e indique a conduta.';
      final out = Tep2026PlantaoResponseGuard.materialize(userInput: input, assistantOutput: 'RAW_LEGACY_INVALID', languageCode: 'pt');
      expect(out, contains('C3R'));
      expect(out, contains('AHA/ACC 2026'));
      expect(out, contains('| Relação VD/VI | **1,2** |'));
      expect(out.toLowerCase(), isNot(contains('wells')));
    });

    test('TEP Spanish alias normalization preserves explicit non-confirmation fail-closed', () {
      const input =
          'Paciente con sospecha de embolia pulmonar aguda, todavía no confirmada. '
          'Solicito orientación diagnóstica; no hay angio-TC confirmatoria.';
      const raw = 'RAW_MODEL_DIAGNOSTIC_LANE';
      final out = Tep2026PlantaoResponseGuard.materialize(
        userInput: input,
        assistantOutput: raw,
        languageCode: 'es',
      );
      expect(out, raw);
    });
    test('IAMCEST Killip I/no congestion resolves iam_supra', () {
      final result = ClinicalReferenceResolver.resolve(
        userText: 'Varón de 58 años con IAMCEST confirmado, Killip I, sin estertores, sin edema, sin congestión ni ingurgitación yugular. ¿Conducta inicial?',
        aiText: '''
🟥 INFARTO AGUDO DE MIOCARDIO CON ELEVACIÓN DEL ST (IAMCEST)
🚨 Conducta inmediata:
* Reperfusión y monitorización.
💊 Tratamiento farmacológico:
* Antiagregación y anticoagulación en categorías separadas.
🔑 Puntos clave:
* Killip I — sin insuficiencia cardíaca ni congestión.
''', lang: 'es');
      expect(result.protocolId, 'iam_supra');
      expect(result.protocolId, isNot('iam_congestao'));
    });

    test('bronquiolitis resolves bronquiolite_aguda, never asthma fallback', () {
      final result = ClinicalReferenceResolver.resolve(
        userText: 'Lactante de 4 meses, primer episodio de sibilancias, cuadro viral típico de bronquiolitis aguda, sin antecedentes de asma.',
        aiText: '''
🟥 BRONQUIOLITIS AGUDA
🚨 Conducta inmediata:
* Soporte, hidratación fraccionada y monitorización.
🔑 Puntos clave:
* No broncodilatadores, corticoides ni antibióticos de rutina.
''', lang: 'es');
      expect(result.protocolId, 'bronquiolite_aguda');
      expect(result.sourceType, 'clinical_protocol');
      expect(result.sourceType, isNot(contains('asthma')));
    });

    test('anaphylaxis disease beats single-drug reference hijack', () {
      final result = ClinicalReferenceResolver.resolve(
        userText: 'Anafilaxia aguda con urticaria, sibilancias e hipotensión tras maní. ¿Conducta inmediata?',
        aiText: '''
🟥 ANAFILAXIA
🚨 Conducta inmediata:
* Adrenalina IM inmediatamente como primera línea.
''', lang: 'es');
      expect(result.protocolId, 'anafilaxia');
      expect(result.sourceType, 'clinical_protocol');
      expect(result.sourceType, isNot('single_drug'));
    });

    test('global title contract exists with PT/ES parity', () {
      final es = AiService.buildM54PhysicalHomologationContractForTesting('Paciente con bronquiolitis aguda. Analiza e indica conducta.', isEs: true);
      final pt = AiService.buildM54PhysicalHomologationContractForTesting('Paciente com bronquiolite aguda. Analise e indique conduta.', isEs: false);
      for (final contract in [es, pt]) { expect(contract, contains('[M54_CONTRATO_TITULO_CLINICO]')); expect(contract, contains('RED FLAGS')); }
      expect(es, contains('PROHIBIDO usar como título principal inicial'));
      expect(es, contains('Conducta clínica'));
      expect(pt, contains('PROIBIDO usar como título principal inicial'));
      expect(pt, contains('Conduta clínica'));
    });

    test('IAMCEST contract separates antiplatelet and anticoagulation lanes', () {
      final es = AiService.buildM54PhysicalHomologationContractForTesting('IAMCEST confirmado, Killip I. Define conducta inicial.', isEs: true);
      final pt = AiService.buildM54PhysicalHomologationContractForTesting('IAMCEST confirmado, Killip I. Defina conduta inicial.', isEs: false);
      expect(es, contains('reperfusión urgente'));
      expect(es, contains('ANTIAGREGACIÓN'));
      expect(es, contains('AAS + inhibidor P2Y12'));
      expect(es, contains('ANTICOAGULACIÓN'));
      expect(es, contains('HNF/HBPM/fondaparinux/bivalirudina'));
      expect(es, contains('oxígeno SOLO si hay hipoxemia'));
      expect(es, contains('Killip es una clasificación clásica I-IV'));
      expect(pt, contains('reperfusão urgente'));
      expect(pt, contains('ANTIAGREGAÇÃO'));
      expect(pt, contains('AAS + inibidor P2Y12'));
      expect(pt, contains('ANTICOAGULAÇÃO'));
      expect(pt, contains('HNF/HBPM/fondaparinux/bivalirudina'));
      expect(pt, contains('oxigênio SOMENTE se houver hipoxemia'));
      expect(pt, contains('Killip é classificação clássica I-IV'));
    });
  });
}

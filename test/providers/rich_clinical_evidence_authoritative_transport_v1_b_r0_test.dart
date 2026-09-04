import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_service.dart';
import 'package:medcases/services/clinical_crosscutting_evidence_resolver.dart';

void main() {
  group('Rich clinical evidence authoritative transport V1-B-R0', () {
    test(
      'Portuguese fluid maintenance surfaces resolve to the curated pack',
      () {
        for (final query in <String>[
          'Adulto 75 kg em manutenção IV. E qual é a classificação?',
          'Manutenção intravenosa no adulto',
          'Manutenção rotineira com fluido IV',
          'Fluido de manutenção IV',
          'Fluido intravenoso de manutenção',
        ]) {
          expect(
            ClinicalCrosscuttingEvidenceResolver.debugMatchId(query),
            'adult_iv_fluid_therapy',
            reason: query,
          );
        }
      },
    );

    test(
      'fluid classification boundary is explicit and sovereign in Plantao',
      () {
        final evidence = ClinicalCrosscuttingEvidenceResolver.enrich(
          query: 'Adulto 75 kg em manutenção IV. E qual é a classificação?',
          baseContext: '',
          lang: 'pt',
        );

        expect(evidence, contains('id=adult_iv_fluid_therapy'));
        expect(evidence, contains('version=2026.09.04.v2'));
        expect(evidence, contains('dados insuficientes'));
        expect(
          evidence,
          contains('Ausência de comorbidades NÃO é evidência de euvolemia'),
        );

        final prompt = AiService.buildClinicalSystemPrompt(
          lang: 'pt',
          matchedProtocolSummaries: const <String>[],
          matchedDrugSummaries: const <String>[],
          userQuery: 'E qual é a classificação?',
          isFirstMessage: false,
          isPlantaoMode: true,
          crosscuttingEvidenceContext: evidence,
        );

        expect(
          prompt,
          contains('[MEDCASES_CROSSCUTTING_AUTHORITATIVE_TRANSPORT_V1]'),
        );
        expect(prompt, contains('dados insuficientes para classificar'));
        expect(
          prompt,
          contains(
            'Uma categoria terapeutica nao equivale automaticamente '
            'a uma classificacao fisiologica do paciente',
          ),
        );
        expect(prompt, contains('id=adult_iv_fluid_therapy'));
      },
    );

    test('norepinephrine evidence carries 2026 access and label facts', () {
      final evidence = ClinicalCrosscuttingEvidenceResolver.enrich(
        query:
            'Choque séptico: noradrenalina, preparo, acesso e contraindicações',
        baseContext: '',
        lang: 'pt',
      );

      expect(evidence, contains('id=norepinephrine_preparation_and_access'));
      expect(evidence, contains('version=2026.09.04.v2'));
      expect(
        evidence,
        contains('NÃO apresentar acesso venoso central como pré-requisito'),
      );
      expect(evidence, contains('não requer diluição adicional'));
      expect(evidence, contains('CONTRAINDICAÇÕES listadas: nenhuma'));
      expect(
        evidence,
        contains('Hiperglicemia não é uma contraindicação absoluta listada'),
      );

      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'pt',
        matchedProtocolSummaries: const <String>[],
        matchedDrugSummaries: const <String>[],
        userQuery: 'E a noradrenalina?',
        isFirstMessage: false,
        isPlantaoMode: true,
        crosscuttingEvidenceContext: evidence,
      );

      expect(
        prompt,
        contains('[MEDCASES_CROSSCUTTING_AUTHORITATIVE_TRANSPORT_V1]'),
      );
      expect(prompt, contains('CONTRAINDICAÇÕES listadas: nenhuma'));
      expect(prompt, contains('não requer diluição adicional'));
      expect(
        prompt,
        contains(
          'nao acrescente contraindicacoes nem regras de acesso '
          'nao sustentadas',
        ),
      );
    });

    test('Spanish evidence has the same no-invention boundary', () {
      final evidence = ClinicalCrosscuttingEvidenceResolver.enrich(
        query:
            'Mantenimiento de fluidos en adulto. ¿Y cuál es la clasificación?',
        baseContext: '',
        lang: 'es',
      );

      expect(evidence, contains('id=adult_iv_fluid_therapy'));
      expect(evidence, contains('datos insuficientes'));
      expect(
        evidence,
        contains('La ausencia de comorbilidades NO demuestra euvolemia'),
      );

      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'es',
        matchedProtocolSummaries: const <String>[],
        matchedDrugSummaries: const <String>[],
        userQuery: '¿Y cuál es la clasificación?',
        isFirstMessage: false,
        isPlantaoMode: true,
        crosscuttingEvidenceContext: evidence,
      );

      expect(
        prompt,
        contains('[MEDCASES_CROSSCUTTING_AUTHORITATIVE_TRANSPORT_V1]'),
      );
      expect(prompt, contains('datos insuficientes para clasificar'));
    });

    test('dedicated crosscutting marker remains Plantao-only', () {
      final evidence = ClinicalCrosscuttingEvidenceResolver.enrich(
        query: 'noradrenalina',
        baseContext: '',
        lang: 'pt',
      );

      final studyPrompt = AiService.buildClinicalSystemPrompt(
        lang: 'pt',
        matchedProtocolSummaries: const <String>[],
        matchedDrugSummaries: const <String>[],
        userQuery: 'noradrenalina',
        isPlantaoMode: false,
        crosscuttingEvidenceContext: evidence,
      );

      expect(
        studyPrompt,
        isNot(contains('[MEDCASES_CROSSCUTTING_AUTHORITATIVE_TRANSPORT_V1]')),
      );
    });

    test(
      'productive owners use 3 dedicated bindings without second provider',
      () {
        final app = File('lib/providers/app_provider.dart').readAsStringSync();
        final ai = File('lib/services/ai_service.dart').readAsStringSync();

        expect('crosscuttingEvidenceContext:'.allMatches(app).length, 3);
        expect("baseContext: '',".allMatches(app).length, 3);
        expect(
          'ClinicalCrosscuttingEvidenceResolver.enrich('.allMatches(app).length,
          3,
        );

        expect(ai, contains('RICH_EVIDENCE_AUTHORITATIVE_TRANSPORT_V1'));
        expect(
          ai,
          contains('[CROSSCUTTING_EVIDENCE] id=\$crosscuttingEvidenceId'),
        );

        final lateOwner = ai.indexOf("'\$ptFullManagementActiveContract'");
        final evidenceOwner = ai.indexOf("'\$ptCrosscuttingEvidenceBlock'");
        expect(lateOwner, greaterThanOrEqualTo(0));
        expect(evidenceOwner, greaterThan(lateOwner));

        for (final forbidden in <String>[
          'crosscuttingEvidenceSecondProvider',
          'callGpt(crosscutting',
          'GeminiService.chat(crosscutting',
          'FirebaseFirestore.instance.collection(\'crosscutting',
        ]) {
          expect(app + ai, isNot(contains(forbidden)), reason: forbidden);
        }
      },
    );

    test('context, persistence, UTF16 and R8 markers remain frozen', () {
      final app = File('lib/providers/app_provider.dart').readAsStringSync();

      for (final marker in <String>[
        'M77_R8_CANONICAL_AUTHORITY_SPECIALTY_GUARD_LOCK_V1',
        'M77_R8_PRE_PERSIST_MACHINE_GATE_V1',
        'M77_CLINICAL_NEW_THREAD_SESSION_ROTATION_V1',
        '_plantaoPersistenceEligibilityByRequest',
        '_removeRejectedAiHistoryTail(',
        'utf16SafeProviderText',
        'forceContext: true',
      ]) {
        expect(app, contains(marker), reason: marker);
      }

      expect(app, isNot(contains('_sessionMemory.resetIfTopicChanged(input)')));
    });
  });
}

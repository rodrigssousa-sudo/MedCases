import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/clinical_crosscutting_evidence_compliance_guard.dart';
import 'package:medcases/services/clinical_crosscutting_evidence_resolver.dart';
import 'package:medcases/services/well_formed_utf16.dart';

void main() {
  group('Rich evidence final compliance + UTF16 closure V1-B-R0', () {
    test('adult fluid Holliday-Segar output is deterministically replaced', () {
      const query =
          'Paciente adulto de 75 kg, sem comorbidades. Quanto de fluido de manutenção devo passar por dia?';
      final evidence = ClinicalCrosscuttingEvidenceResolver.enrich(
        query: query,
        baseContext: '',
        lang: 'pt',
      );
      expect(evidence, contains('id=adult_iv_fluid_therapy'));

      final result = ClinicalCrosscuttingEvidenceComplianceGuard.enforce(
        query: query,
        assistantOutput:
            'Usar Holliday-Segar: 4 ml/kg + 2 ml/kg + 1 ml/kg = 115 ml/h.',
        lang: 'pt',
        evidenceContext: evidence,
      );

      expect(result.modified, isTrue);
      expect(result.evidenceId, 'adult_iv_fluid_therapy');
      expect(result.text, contains('25–30 mL/kg/dia'));
      expect(result.text, contains('1875–2250 mL/dia'));
      expect(result.text, contains('78–94 mL/h'));
      expect(
        result.text,
        contains(
          'não deve ser usada como fórmula padrão de manutenção no adulto',
        ),
      );
      expect(result.text, isNot(contains('Usar Holliday-Segar:')));
      expect(WellFormedUtf16.isWellFormed(result.text), isTrue);
    });

    test('unsupported fluid classification is replaced by supported axis', () {
      const expanded =
          'Paciente adulto de 75 kg em manutenção IV. E qual a classificação?';
      final evidence = ClinicalCrosscuttingEvidenceResolver.enrich(
        query: expanded,
        baseContext: '',
        lang: 'pt',
      );

      final result = ClinicalCrosscuttingEvidenceComplianceGuard.enforce(
        query: 'E qual a classificação?',
        assistantOutput:
            'Classificação do paciente: Estável. Sem sinais de desidratação ou sobrecarga. Estável e adequado para fluidos de manutenção.',
        lang: 'pt',
        evidenceContext: evidence,
      );

      expect(result.modified, isTrue);
      expect(
        result.text,
        contains('Categoria terapêutica: manutenção IV rotineira'),
      );
      expect(result.text, contains('dados insuficientes para classificar'));
      expect(
        result.text,
        contains('euvolêmico, hipovolêmico ou hipervolêmico'),
      );
      expect(
        result.text,
        isNot(contains('Classificação do paciente: Estável')),
      );
    });

    test('norepinephrine unsupported access and label claims are replaced', () {
      const query =
          'Paciente adulto em choque séptico, necessitando noradrenalina. Como preparar e por qual acesso posso iniciar?';
      final evidence = ClinicalCrosscuttingEvidenceResolver.enrich(
        query: query,
        baseContext: '',
        lang: 'pt',
      );
      expect(evidence, contains('id=norepinephrine_preparation_and_access'));

      final result = ClinicalCrosscuttingEvidenceComplianceGuard.enforce(
        query: query,
        assistantOutput:
            'Acesso venoso central é ideal. Contraindicações absolutas: hiperglicemia grave não tratada e choque hipovolêmico não corrigido.',
        lang: 'pt',
        evidenceContext: evidence,
      );

      expect(result.modified, isTrue);
      expect(
        result.text,
        contains('Não atrasar o início aguardando acesso venoso central'),
      );
      expect(result.text, contains('acesso periférico adequado'));
      expect(result.text, contains('não requer diluição adicional'));
      expect(result.text, contains('contraindicações listadas: nenhuma'));
      expect(
        result.text,
        contains('hiperglicemia não é contraindicação absoluta listada'),
      );
    });

    test('compliant evidence output remains unchanged', () {
      const query = 'Fluido de manutenção em adulto de 70 kg';
      final evidence = ClinicalCrosscuttingEvidenceResolver.enrich(
        query: query,
        baseContext: '',
        lang: 'pt',
      );
      const output =
          'Manutenção IV rotineira: 25–30 mL/kg/dia, ajustada conforme clínica, perdas, balanço e exames.';

      final result = ClinicalCrosscuttingEvidenceComplianceGuard.enforce(
        query: query,
        assistantOutput: output,
        lang: 'pt',
        evidenceContext: evidence,
      );

      expect(result.modified, isFalse);
      expect(result.text, output);
    });

    test('no evidence profile is a strict no-op', () {
      final result = ClinicalCrosscuttingEvidenceComplianceGuard.enforce(
        query: 'cefaleia',
        assistantOutput: 'Avaliar sinais de alarme.',
        lang: 'pt',
        evidenceContext: '',
      );
      expect(result.modified, isFalse);
      expect(result.text, 'Avaliar sinais de alarme.');
      expect(result.evidenceId, isNull);
    });

    test('AppProvider compliance precedes persistence and UI handoff', () {
      final source = File('lib/providers/app_provider.dart').readAsStringSync();

      expect(
        source,
        contains(
          "import '../services/clinical_crosscutting_evidence_compliance_guard.dart';",
        ),
      );
      expect(
        source,
        contains('String _applyCrosscuttingEvidenceComplianceGuard({'),
      );
      expect(source, contains('[CROSSCUTTING_COMPLIANCE]'));
      expect(
        'ClinicalCrosscuttingEvidenceResolver.enrich('
            .allMatches(source)
            .length,
        3,
        reason:
            'the original three productive enriched prompt bindings are frozen',
      );
      expect(
        'ClinicalCrosscuttingEvidenceResolver.resolve('
            .allMatches(source)
            .length,
        2,
        reason:
            'post-provider compliance may resolve IDs but must not add enrich bindings',
      );

      final finalizerStart = source.indexOf(
        'Future<void> _finalizeGptSuccessfulRequest({',
      );
      final persistenceBoundary = source.indexOf(
        '// ── Step B: Atomic Persistence',
        finalizerStart,
      );
      final finalizer = source.substring(finalizerStart, persistenceBoundary);
      expect(finalizer, contains('_applyCrosscuttingEvidenceComplianceGuard('));
      expect(
        finalizer,
        contains('safeOutput = WellFormedUtf16.normalize(safeOutput);'),
      );

      final wrapperStart = source.indexOf(
        'void Function(String, [ClinicalStructuredOutput?]) wrappedOnDone',
      );
      final wrapperEnd = source.indexOf(
        '// PHASE 3D — run canonical finalization',
        wrapperStart,
      );
      final wrapper = source.substring(wrapperStart, wrapperEnd);
      final consistency = wrapper.indexOf(
        'PlantaoClinicalResponseConsistencyGuard.enforce(',
      );
      final compliance = wrapper.indexOf(
        '_applyCrosscuttingEvidenceComplianceGuard(',
      );
      final utf16 = wrapper.indexOf('WellFormedUtf16.normalize(guardedText)');
      final ui = wrapper.indexOf('onDone(guardedText);');

      expect(consistency, greaterThanOrEqualTo(0));
      expect(compliance, greaterThan(consistency));
      expect(utf16, greaterThan(compliance));
      expect(ui, greaterThan(utf16));

      final persistStart = source.indexOf(
        'Future<SessionPersistStatus> persistAiExchangeOnce({',
      );
      final persistEnd = source.indexOf(
        '// M74B_POST_FINAL_PRESENTATION_RECONCILIATION_V1',
        persistStart,
      );
      final persistOwner = source.substring(persistStart, persistEnd);
      expect(persistOwner, contains('evidenceCompliantAssistantOutput'));
      expect(
        persistOwner.indexOf('_applyCrosscuttingEvidenceComplianceGuard('),
        lessThan(persistOwner.indexOf('WellFormedUtf16.normalize(userInput)')),
      );
    });

    test(
      'AiScreen has the last UTF16 boundary after M58 and before commit',
      () {
        final source = File('lib/screens/ai_screen.dart').readAsStringSync();
        expect(
          source,
          contains("import '../services/well_formed_utf16.dart';"),
        );

        final onDone = source.indexOf('onDone: (finalText) {');
        final m73 = source.indexOf(
          'M73B_TYPED_RICH_PHASES_FINAL_COMPLETENESS_RUNTIME_V1',
          onDone,
        );
        final m58 = source.indexOf(
          'M58_MACHINE_NATIVE_FINAL_COMMIT_FAIL_CLOSED',
          m73,
        );
        final utf16 = source.indexOf('M77_FINAL_UI_UTF16_BOUNDARY_V1', m58);
        final visible = source.indexOf('text: safeFinalText,', utf16);

        expect(onDone, greaterThanOrEqualTo(0));
        expect(m73, greaterThan(onDone));
        expect(m58, greaterThan(m73));
        expect(utf16, greaterThan(m58));
        expect(visible, greaterThan(utf16));

        final boundary = source.substring(utf16, visible);
        expect(
          boundary,
          contains('safeFinalText = WellFormedUtf16.normalize(safeFinalText);'),
        );
      },
    );

    test('frozen context and R7/R8 contracts remain present', () {
      final app = File('lib/providers/app_provider.dart').readAsStringSync();
      final guard = File(
        'lib/services/clinical_crosscutting_evidence_compliance_guard.dart',
      ).readAsStringSync();

      for (final marker in <String>[
        'M77_R8_CANONICAL_AUTHORITY_SPECIALTY_GUARD_LOCK_V1',
        'M77_R8_PRE_PERSIST_MACHINE_GATE_V1',
        'M77_CLINICAL_NEW_THREAD_SESSION_ROTATION_V1',
        '_plantaoPersistenceEligibilityByRequest',
        '_removeRejectedAiHistoryTail(',
        'forceContext: true',
        'onDone(guardedText);',
      ]) {
        expect(app, contains(marker), reason: marker);
      }
      expect(app, isNot(contains('_sessionMemory.resetIfTopicChanged(input)')));

      for (final forbidden in <String>[
        'ProviderRouterService',
        'GeminiService',
        'FirebaseFirestore',
        'callGpt',
        'callPaidProxy',
      ]) {
        expect(guard, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('M77 R8 final cross-pathology follow-up + pre-persist fail-close', () {
    late String app;
    late String ai;

    setUpAll(() {
      app = File('lib/providers/app_provider.dart').readAsStringSync();
      ai = File('lib/screens/ai_screen.dart').readAsStringSync();
    });

    test('authoritative context prevents stale IAM specialty promotion', () {
      expect(app, contains('M77_R8_CANONICAL_AUTHORITY_SPECIALTY_GUARD_LOCK_V1'));
      expect(app, contains('m77BlockIamHistoryPromotion'));
      expect(app, contains('canonicalPlantaoAuthority'));
      expect(app, contains('canonicalPlantaoPathologyKey'));
      expect(app, contains('current_turn_identity_mismatch'));
      expect(
        app.indexOf('m77BlockIamHistoryPromotion'),
        lessThan(
          app.indexOf('PlantaoIamcestKillipClassificationGuard.materialize('),
        ),
      );
    });

    test('critical machine-native output cannot persist before UI fail-closed', () {
      expect(app, contains('M77_R8_PRE_PERSIST_MACHINE_GATE_V1'));
      expect(app, contains('final m77PersistenceEligible ='));
      expect(app, contains('plantaoPersistenceEligibilityGate(safeOutput)'));
      expect(app, contains('eligible=false persistence=skipped'));
      expect(
        app.indexOf('final m77PersistenceEligible ='),
        lessThan(app.indexOf('await persistAiExchangeOnce(')),
      );
    });

    test('UI eligibility mirror uses same machine gate and M62 repair seam', () {
      expect(ai, contains('M77_R8_PRE_PERSIST_MACHINE_GATE_V1'));
      expect(ai, contains('m77PlantaoPersistenceEligibilityGate'));
      expect(ai, contains('PlantaoGlobalClinicalResponseGate.finalizeForPresentation('));
      expect(ai, contains('repairEvidenceBackedRequiredActionsForPresentation('));
      expect(ai, contains('contextPack: m56cMachineContext.contextPack'));
      expect(ai, contains('plantaoPersistenceEligibilityGate: !_longResponse'));
    });

    test('no second provider call is introduced by the pre-persist gate', () {
      final start = ai.indexOf('// M77_R8_PRE_PERSIST_MACHINE_GATE_V1');
      final end = ai.indexOf('await p.sendAiMessage(', start);
      expect(start, isNonNegative);
      expect(end, greaterThan(start));
      final block = ai.substring(start, end);
      expect(block, isNot(contains('callGptProxy(')));
      expect(block, isNot(contains('sendAiMessage(')));
      expect(block, isNot(contains('Gemini')));
    });

    test('R7 physical closure markers remain present', () {
      final thread = File('lib/services/clinical_thread_manager.dart').readAsStringSync();
      final consistency = File(
        'lib/services/ai_pipeline/plantao_clinical_response_consistency_guard.dart',
      ).readAsStringSync();
      expect(thread, contains('M77_SHORT_PROMPT_GENERIC_TASK_TOKEN_FILTER_V1'));
      expect(consistency, contains('R7_R1_HEMOTHORAX_IDEMPOTENCY_ORDER_V1'));
      expect(app, contains('M77_CLINICAL_NEW_THREAD_SESSION_ROTATION_V1'));
    });
  });
}

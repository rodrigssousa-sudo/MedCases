import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantao pharma evidence/provenance/typed-regimen B-R0', () {
    final app = File('lib/providers/app_provider.dart').readAsStringSync();
    final guardia = File(
      'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
    ).readAsStringSync();
    final adapter = File(
      'lib/services/ai_pipeline/plantao_local_clinical_output_adapter.dart',
    ).readAsStringSync();
    final resolver = File(
      'lib/screens/ai/widgets/clinical_reference_resolver.dart',
    ).readAsStringSync();

    test('fallback is finalized-visible-RX based and shadow only', () {
      expect(
        app,
        contains('PLANTAO_FINALIZED_VISIBLE_MEDICATION_EVIDENCE_FALLBACK_V1'),
      );
      expect(app, contains('clinicalOutput.prescricao'));
      expect(app, contains('finalized_visible_medication_identity_fallback'));
      expect(app, contains('[PLANTAO_DRUG_EVIDENCE_FINALIZED_RX_FALLBACK]'));
      expect(
        app,
        contains(
          '_plantaoDrugEvidenceRequestObserver.adapter.retrieveTypedTerms(',
        ),
      );
      expect(
        app,
        contains('finalized_visible_medication_typed_terms_fallback'),
      );
      expect(
        app,
        contains('_plantaoDrugEvidenceFinalizationJoinShadowAdapter.join('),
      );
      expect(app, contains('if (fallbackJoin.isReady)'));
      expect(app, contains('drugEvidenceJoin = fallbackJoin;'));
    });

    test('original evidence remains first choice', () {
      final marker = app.indexOf(
        'PLANTAO_FINALIZED_VISIBLE_MEDICATION_EVIDENCE_FALLBACK_V1',
      );
      expect(marker, greaterThanOrEqualTo(0));
      final tail = app.substring(marker, (marker + 8000).clamp(0, app.length));

      final originalJoin = tail.indexOf(
        'drugEvidenceFuture: _plantaoDrugEvidenceRequestFuture',
      );
      final fallbackGate = tail.indexOf('if (!drugEvidenceJoin.isReady &&');
      expect(originalJoin, greaterThanOrEqualTo(0));
      expect(fallbackGate, greaterThan(originalJoin));
    });

    test('fallback is auditable and does not fake typed regimen', () {
      expect(app, contains('supportsMedicationMaterialization'));
      expect(
        app,
        isNot(contains('drugTypedRegimens = finalizedMedicationIdentities')),
      );
      expect(app, isNot(contains('drugProvenance = "identityEvidenceBound"')));
      expect(app, isNot(contains('medicationMaterializationEnabled = true')));
    });

    test('productive drug shadow boundaries stay disabled', () {
      final evidence = File(
        'lib/services/ai_pipeline/plantao/shadow/'
        'plantao_drug_evidence_shadow_adapter.dart',
      ).readAsStringSync();
      final join = File(
        'lib/services/ai_pipeline/plantao/shadow/'
        'plantao_drug_evidence_finalization_join_shadow_adapter.dart',
      ).readAsStringSync();
      final provenance = File(
        'lib/services/ai_pipeline/plantao/shadow/'
        'plantao_drug_identity_provenance_binding_shadow_adapter.dart',
      ).readAsStringSync();

      expect(evidence, contains('static const bool renderingEnabled = false;'));
      expect(
        evidence,
        contains('static const bool persistenceEnabled = false;'),
      );
      expect(
        evidence,
        contains('static const bool medicationMaterializationEnabled = false;'),
      );
      expect(
        join,
        contains('static const bool productiveRenderingConnected = false;'),
      );
      expect(
        join,
        contains('static const bool productivePersistenceConnected = false;'),
      );
      expect(
        provenance,
        contains('static const bool productiveRenderingConnected = false;'),
      );
      expect(
        provenance,
        contains('static const bool productivePersistenceConnected = false;'),
      );
    });

    test('Super Build A physical fixes remain structurally frozen', () {
      expect(
        guardia,
        contains('PLANTAO_PRESENTATION_IDENTITY_LONG_FORM_TASK_TITLE_V1'),
      );
      expect(
        guardia,
        contains('PLANTAO_PRESENTATION_STEMI_LONG_FORM_EQUIVALENCE_V2'),
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

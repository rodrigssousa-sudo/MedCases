import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantao physical classification grounding/render V1-B-R0', () {
    test(
      'dependent classification can retrieve protocol from active topic',
      () {
        final app = File('lib/providers/app_provider.dart').readAsStringSync();

        expect(
          app,
          contains('PLANTAO_CLASSIFICATION_CONTEXTUAL_RAG_FALLBACK_V1'),
        );
        expect(
          app,
          contains("_threadManager.activeTopic.replaceAll('_', ' ')"),
        );
        expect(app, contains('[PLANTAO_CLASSIFICATION_CONTEXT_RAG]'));
        expect(app, contains('contextualMatches'));
      },
    );

    test('negated pulmonary edema cannot activate acute HF guard', () {
      final ai = File('lib/services/ai_service.dart').readAsStringSync();

      expect(ai, contains('PLANTAO_AHF_NEGATION_GUARD_V1'));
      expect(ai, contains("'sin edema agudo de pulmon'"));
      expect(ai, contains("'sem edema agudo de pulmao'"));
      expect(ai, contains('!hasNegatedAcuteHeartFailure'));
    });

    test('classification answer is patient-first and render-safe', () {
      final ai = File('lib/services/ai_service.dart').readAsStringSync();

      expect(ai, contains('PLANTAO_PATIENT_FIRST_CLASSIFICATION_RENDER_V1'));
      expect(ai, contains('CLASIFICAR AL PACIENTE ACTUAL'));
      expect(ai, contains('CLASSIFICAR O PACIENTE ATUAL'));
      expect(ai, contains('🔑 Puntos clave:'));
      expect(ai, contains('🔑 Pontos-chave:'));
      expect(ai, contains('Clasificación final:'));
      expect(ai, contains('Classificacao final:'));
    });

    test(
      'IAM database already contains actionable patient classifications',
      () {
        final proto = File(
          'lib/data/protocols_database.dart',
        ).readAsStringSync();

        expect(proto, contains('Killip I'));
        expect(proto, contains('IAMCEST anterior'));
        expect(proto, contains('classification:'));
        expect(proto, contains('severityCriteria:'));
      },
    );

    test('TEP deterministic classification owner remains untouched', () {
      final tep = File(
        'lib/services/tep_2026_plantao_response_guard.dart',
      ).readAsStringSync();

      expect(tep, contains('CLASIFICACIÓN AHA/ACC 2026'));
      expect(tep, contains('**E2:**'));
    });
  });
}

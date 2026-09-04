import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_service.dart';

void main() {
  group('Plantao active classification prompt/shadow propagation V2-B-R0', () {
    test(
      'Spanish classification contract is present in actual Plantao prompt',
      () {
        final prompt = AiService.buildClinicalSystemPrompt(
          lang: 'es',
          matchedProtocolSummaries: const <String>[
            'PROTOCOLO_CLINICO_ATIVO: IAMCEST',
            'CLASIFICACION_VERIFICADA: IAMCEST anterior según topografía compatible.',
            'CRITERIOS_DE_GRAVEDAD: clasificar Killip según congestión y shock.',
          ],
          matchedDrugSummaries: const <String>[],
          userQuery: '¿Y cuál es la clasificación?',
          isFirstMessage: false,
          isPlantaoMode: true,
        );

        expect(prompt, contains('[PLANTAO_CLASSIFICATION_ACTIVE_CONTRACT_V2]'));
        expect(prompt, contains('CLASIFICACIÓN DEL PACIENTE'));
        expect(prompt, contains('Clasificación final:'));
        expect(prompt, contains('CLASIFICACION_VERIFICADA'));
        expect(prompt, contains('NO inferir IAM tipo 1'));
        expect(prompt, contains('IAM con elevación persistente del ST'));
      },
    );

    test(
      'Portuguese classification contract is present in actual Plantao prompt',
      () {
        final prompt = AiService.buildClinicalSystemPrompt(
          lang: 'pt',
          matchedProtocolSummaries: const <String>[
            'PROTOCOLO_CLINICO_ATIVO: IAMCSST',
            'CLASSIFICACAO_VERIFICADA: IAMCSST anterior conforme topografia compatível.',
          ],
          matchedDrugSummaries: const <String>[],
          userQuery: 'E qual é a classificação?',
          isFirstMessage: false,
          isPlantaoMode: true,
        );

        expect(prompt, contains('[PLANTAO_CLASSIFICATION_ACTIVE_CONTRACT_V2]'));
        expect(prompt, contains('CLASSIFICAÇÃO DO PACIENTE'));
        expect(prompt, contains('Classificação final:'));
        expect(prompt, contains('NÃO inferir IAM tipo 1'));
      },
    );

    test(
      'classification V2 contract is Plantao-only and absent from Study output',
      () {
        final prompt = AiService.buildClinicalSystemPrompt(
          lang: 'es',
          matchedProtocolSummaries: const <String>[],
          matchedDrugSummaries: const <String>[],
          userQuery: '¿Y cuál es la clasificación?',
          isFirstMessage: false,
          isPlantaoMode: false,
        );

        expect(
          prompt,
          isNot(contains('[PLANTAO_CLASSIFICATION_ACTIVE_CONTRACT_V2]')),
        );
      },
    );

    test(
      'non-classification Plantao query does not inject V2 classification task',
      () {
        final prompt = AiService.buildClinicalSystemPrompt(
          lang: 'es',
          matchedProtocolSummaries: const <String>[],
          matchedDrugSummaries: const <String>[],
          userQuery: '¿Y el tratamiento?',
          isFirstMessage: false,
          isPlantaoMode: true,
        );

        expect(
          prompt,
          isNot(contains('[PLANTAO_CLASSIFICATION_ACTIVE_CONTRACT_V2]')),
        );
      },
    );

    test(
      'AppProvider propagates contextual matches into caller protocol list',
      () {
        final app = File('lib/providers/app_provider.dart').readAsStringSync();

        expect(
          app,
          contains(
            'PLANTAO_CLASSIFICATION_CONTEXTUAL_RAG_SHADOW_PROPAGATION_V2',
          ),
        );
        expect(app, contains('required List<ProtocolModel> protocols,'));
        expect(app, contains('protocols.add(contextualProtocol);'));
        expect(app, contains(r'propagatedToCaller=$propagatedToCaller'));
      },
    );

    test('R2 safeguards and global/TEP owners remain present', () {
      final ai = File('lib/services/ai_service.dart').readAsStringSync();
      final app = File('lib/providers/app_provider.dart').readAsStringSync();
      final tep = File(
        'lib/services/tep_2026_plantao_response_guard.dart',
      ).readAsStringSync();

      expect(ai, contains('PLANTAO_AHF_NEGATION_GUARD_V1'));
      expect(ai, contains('PLANTAO_PATIENT_FIRST_CLASSIFICATION_RENDER_V1'));
      expect(
        app,
        contains('PLANTAO_CLASSIFICATION_CONTEXTUAL_RAG_FALLBACK_V1'),
      );
      expect(app, contains('PLANTAO_GLOBAL_CLASSIFICATION_TRANSPORT_V1'));
      expect(tep, contains('CLASIFICACIÓN AHA/ACC 2026'));
    });
  });
}

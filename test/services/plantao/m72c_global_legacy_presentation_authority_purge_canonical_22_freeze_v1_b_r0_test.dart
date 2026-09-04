import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/plantao_iamcest_killip_classification_guard.dart';

void main() {
  group('M72C global legacy presentation authority purge', () {
    test(
      'canonical 22 registry remains the single typed response-model owner',
      () {
        final source = File(
          'lib/services/ai_pipeline/plantao/contracts/plantao_response_contract.dart',
        ).readAsStringSync();

        final enumBody = RegExp(
          r'enum\s+PlantaoResponseModelId\s*\{([\s\S]*?)\}',
        ).firstMatch(source)!.group(1)!;
        final ids = enumBody
            .replaceAll(RegExp(r'//.*'), '')
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        expect(ids.length, 22);
        expect(
          RegExp(
            r'id\s*:\s*PlantaoResponseModelId\.',
          ).allMatches(source).length,
          22,
        );
        expect(
          RegExp(r'legacyMatrixNumber\s*:\s*\d+').allMatches(source).length,
          22,
        );
      },
    );

    test('legacy response-format constants are physically removed', () {
      final source = File('lib/services/ai_service.dart').readAsStringSync();
      expect(source, isNot(contains('static const _responseFormatEs')));
      expect(source, isNot(contains('static const _responseFormatPt')));
      expect(source, contains('M58_MACHINE_NATIVE_SYSTEM_PROMPT_V1'));
      expect(
        source,
        contains(
          'M63_MACHINE_NATIVE_REQUIRED_ACTION_ATOMIC_PROMPT_COMPLIANCE_V1',
        ),
      );
    });

    test('ResponseReformatter authority and class are physically removed', () {
      final screen = File('lib/screens/ai_screen.dart').readAsStringSync();
      final pipeline = File(
        'lib/services/plantao_pipeline.dart',
      ).readAsStringSync();

      expect(
        screen,
        contains('M72C_GLOBAL_LEGACY_PRESENTATION_AUTHORITY_PURGE_V1'),
      );
      expect(screen, isNot(contains('ResponseReformatter.')));
      expect(pipeline, isNot(contains('class ResponseReformatter')));
      expect(pipeline, contains('class PlantaoParser'));
      expect(pipeline, contains('class PlantaoOrganizer'));
    });

    test('global gate remains presentation hygiene owner', () {
      final gate = File(
        'lib/services/plantao_global_clinical_response_gate.dart',
      ).readAsStringSync();

      expect(
        gate,
        contains(
          'M70C_PRE_DEDUP_MACHINE_VALIDATION_POST_DEDUP_PRESENTATION_V1',
        ),
      );
      expect(gate, contains('_stripDecorativePictographs'));
    });

    test('non-IAM output is byte-exact through IAM owner', () {
      const raw =
          '🟥 ANAFILAXIA\n🚨 Conducta inmediata: ADRENALINA IM primero.';
      final out = PlantaoIamcestKillipClassificationGuard.materialize(
        userInput:
            'Paciente con reacción aguda después de medicación, urticaria, '
            'disnea e hipotensión.',
        assistantOutput: raw,
        languageCode: 'es',
        recentUserTurns: const <String>[
          'Paciente previo con IAMCEST, elevación de ST V2-V5.',
        ],
      );
      expect(out, raw);
    });

    test('stale IAM history cannot cross a new clinical case', () {
      const raw = '🟥 RESPUESTA DE OTRO CASO';
      final out = PlantaoIamcestKillipClassificationGuard.materialize(
        userInput: '¿Y cuál es la clasificación?',
        assistantOutput: raw,
        languageCode: 'es',
        recentUserTurns: const <String>[
          'Paciente de 62 años con IAMCEST confirmado.',
          'Paciente con nuevo cuadro clínico, SpO2 88%.',
        ],
      );
      expect(out, raw);
      expect(out, isNot(contains('Killip')));
    });

    test('canonical matrix bridge remains active compatibility, not purged', () {
      final contract = File(
        'lib/services/ai_pipeline/plantao/contracts/plantao_response_contract.dart',
      ).readAsStringSync();
      final resolver = File(
        'lib/services/ai_pipeline/plantao/contracts/plantao_response_shadow_resolver.dart',
      ).readAsStringSync();
      final gateway = File(
        'lib/services/ai_gateway_service.dart',
      ).readAsStringSync();

      expect(contract, contains('legacyMatrixNumber'));
      expect(contract, contains('byLegacyMatrix'));
      expect(resolver, contains('legacyMatrixNumber'));
      expect(gateway, contains('legacyMatrixNumber'));
    });

    test('parser and organizer remain active compatibility owners', () {
      final pipeline = File(
        'lib/services/plantao_pipeline.dart',
      ).readAsStringSync();
      final adapter = File(
        'lib/services/ai_pipeline/plantao_local_clinical_output_adapter.dart',
      ).readAsStringSync();

      expect(pipeline, contains('class PlantaoParser'));
      expect(pipeline, contains('class PlantaoOrganizer'));
      expect(adapter, contains('PlantaoParser'));
    });

    test('M71D and global gate runtime seams remain frozen', () {
      final app = File('lib/providers/app_provider.dart').readAsStringSync();
      final screen = File('lib/screens/ai_screen.dart').readAsStringSync();

      expect(app, contains('M71D_RUNTIME_ATTESTATION_PROVIDER_GATE_V1'));
      expect(screen, contains('M71D_RUNTIME_ATTESTATION_BINDING_V1'));
      expect(
        screen,
        contains('PlantaoGlobalClinicalResponseGate.finalizeForPresentation('),
      );
    });
  });
}

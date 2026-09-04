import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String region(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  final end = source.indexOf(endMarker, start);

  expect(start, greaterThanOrEqualTo(0), reason: startMarker);
  expect(end, greaterThan(start), reason: endMarker);

  return source.substring(start, end);
}

void main() {
  late String source;
  late String waiting;
  late String stages;

  setUpAll(() {
    source = File('lib/screens/ai_screen.dart').readAsStringSync();
    waiting = region(
      source,
      'if (_thinking && i == _messages.length)',
      'final msg = _messages[i];',
    );
    stages = region(
      source,
      'class _AiClinicalGenerationStages extends StatefulWidget',
      'class _AiResponseIdentityHeader extends StatelessWidget',
    );
  });

  group('AI clinical generation stages V1', () {
    test(
      'waiting state upgrades from dots-only to clinical stage experience',
      () {
        expect(waiting, contains('_AiClinicalGenerationStages('));
        expect(waiting, isNot(contains('_AiResponseIdentityHeader(')));
        expect(waiting, isNot(contains('AiShimmerDots(dark: dark)')));
        expect(
          waiting,
          contains("p.lang.trim().toLowerCase().startsWith('es')"),
        );
      },
    );

    test('Portuguese and Spanish clinical generation copy is complete', () {
      for (final token in const <String>[
        'Construindo sua resposta',
        'Revisando referências científicas relevantes',
        'Organizando a resposta',
        'Repassando detalhes clínicos',
        'Construyendo tu respuesta',
        'Revisando referencias científicas relevantes',
        'Organizando la respuesta',
        'Repasando detalles clínicos',
      ]) {
        expect(stages, contains(token), reason: token);
      }
    });

    test(
      'premium visual hierarchy uses canonical green and staged emphasis',
      () {
        expect(
          source,
          contains('AI_CLINICAL_GENERATION_STAGES_V1'),
          reason: 'owner marker lives immediately before the class region',
        );

        for (final token in const <String>[
          'const brandGreen = Color(0xFF009C3B);',
          'duration: const Duration(milliseconds: 6000)',
          'duration: const Duration(milliseconds: 1800)',
          "ValueKey('ai-clinical-generation-stages')",
          "ValueKey('ai-clinical-generation-activity-rail')",
          'FontWeight.w700',
          'FontWeight.w400',
          'LinearGradient(',
        ]) {
          expect(stages, contains(token), reason: token);
        }
      },
    );

    test('visual stage sequence does not claim fake telemetry or ETA', () {
      for (final forbidden in const <String>[
        'LinearProgressIndicator(',
        'CircularProgressIndicator(',
        'percent',
        'percentage',
        'ETA',
        'estimativa',
        'estimación',
        'etapa 1 de',
        'stage 1 of',
        'check_circle',
        'Icons.check',
        'FirebaseFirestore',
        'RemoteConfig',
        'StreamController',
        'sendAiMessage(',
        'AiGateway',
        'AiService',
        'PlantaoPipeline',
        'GuardiaClinicalResponseView',
      ]) {
        expect(stages, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('last visual stage remains active instead of looping stage order', () {
      expect(stages, contains('if (value < 0.75) return 2;'));
      expect(stages, contains('return 3;'));
      expect(stages, contains('duration: const Duration(milliseconds: 6000)'));
      expect(stages, contains(')..forward();'));
      expect(stages, isNot(contains('_stageController.repeat')));
    });
  });
}

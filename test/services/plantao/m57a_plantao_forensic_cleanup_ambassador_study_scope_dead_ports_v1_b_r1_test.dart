import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String sliceBetween(String source, String startToken, String endToken) {
  final start = source.indexOf(startToken);
  expect(start, greaterThanOrEqualTo(0), reason: 'missing $startToken');
  final end = source.indexOf(endToken, start + startToken.length);
  expect(end, greaterThan(start), reason: 'missing $endToken');
  return source.substring(start, end);
}

void main() {
  late String screen;
  late String ambassador;
  late String persistence;
  late String provider;
  late String legacy;
  late String appPipeline;

  setUpAll(() {
    screen = File('lib/screens/ai_screen.dart').readAsStringSync();
    ambassador = File(
      'lib/screens/ai/widgets/ambassador_panel.dart',
    ).readAsStringSync();
    persistence = File(
      'lib/services/ai_pipeline/plantao/ports/plantao_persistence_port.dart',
    ).readAsStringSync();
    provider = File(
      'lib/services/ai_pipeline/plantao/ports/plantao_provider_port.dart',
    ).readAsStringSync();
    legacy = File(
      'lib/services/ai_pipeline/ai_legacy_callback_pipeline.dart',
    ).readAsStringSync();
    appPipeline = File(
      'lib/services/ai_pipeline/app_provider_ai_response_pipeline.dart',
    ).readAsStringSync();
  });

  test(
    'AiScreen has one productive p.sendAiMessage await and no VIP duplicate',
    () {
      expect(
        RegExp(r'await\s+p\.sendAiMessage\s*\(').allMatches(screen).length,
        1,
      );
      final ambassadorMethod = sliceBetween(
        screen,
        'void _openAmbassadorPanel()',
        '@override',
      );
      expect(ambassadorMethod, isNot(contains('p.sendAiMessage(')));
      expect(ambassadorMethod, isNot(contains('onSecondOpinion:')));
    },
  );

  test(
    'VIP second opinion is explicitly Study-only and not Plantao default',
    () {
      expect(
        RegExp(
          r'await\s+widget\.provider\.sendAiMessage\s*\(',
        ).allMatches(ambassador).length,
        1,
      );
      final callStart = ambassador.indexOf(
        'await widget.provider.sendAiMessage(',
      );
      final call = ambassador.substring(
        callStart,
        ambassador.indexOf('onChunk:', callStart),
      );
      expect(call, contains('longResponse: true'));
      expect(ambassador, isNot(contains('onSecondOpinion')));
      expect(ambassador, contains('MarkdownBody('));
    },
  );

  test('Plantao renderer separation remains canonical', () {
    expect(screen, contains('GuardiaClinicalResponseView('));
    expect(screen, contains('final bool useGuardiaPresentation ='));
    expect(screen, contains('!_longResponse'));
    expect(screen, contains('AiBubble('));
  });

  test('only proven dead port symbols are removed', () {
    expect(persistence, isNot(contains('class PlantaoPersistencePlan')));
    expect(persistence, contains('class PlantaoPersistencePort'));
    expect(persistence, contains('PlantaoPersistenceWriteReceipt'));

    expect(provider, isNot(contains('class PlantaoProviderPort {')));
    expect(provider, contains('PlantaoProviderKind'));
    expect(provider, contains('PlantaoProviderInvocation'));
    expect(provider, contains('PlantaoProviderPortEvent'));
  });

  test('active legacy compatibility transport remains present', () {
    expect(legacy, contains('class LegacyCallbackAiResponsePipeline'));
    expect(appPipeline, contains('ai_legacy_callback_pipeline.dart'));
    expect(appPipeline, contains('LegacyCallbackAiResponsePipeline'));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _body(String source, String name) {
  final match = RegExp(
    'Future<bool>\\s+${RegExp.escape(name)}\\s*\\(',
  ).firstMatch(source);
  expect(match, isNotNull);

  final parametersOpen = source.indexOf('(', match!.start);
  expect(parametersOpen, greaterThanOrEqualTo(0));

  var parentheses = 0;
  var parametersClose = -1;
  for (
    var index = parametersOpen;
    index < source.length;
    index++
  ) {
    if (source[index] == '(') parentheses++;
    if (source[index] == ')') {
      parentheses--;
      if (parentheses == 0) {
        parametersClose = index;
        break;
      }
    }
  }
  expect(parametersClose, greaterThan(parametersOpen));

  final open = source.indexOf('{', parametersClose);
  expect(open, greaterThan(parametersClose));

  var depth = 0;
  for (var index = open; index < source.length; index++) {
    if (source[index] == '{') depth++;
    if (source[index] == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(open + 1, index);
      }
    }
  }
  fail('Unbalanced method: $name');
}

void main() {
  group('Phase3K-B3 private core', () {
    test('selector, bridge and private core have one owner', () {
      final source = File(
        'lib/providers/app_provider.dart',
      ).readAsStringSync();

      expect(
        RegExp(r'Future<bool>\s+sendAiMessage\s*\(')
            .allMatches(source)
            .length,
        1,
      );
      expect(
        RegExp(r'Future<bool>\s+sendAiMessageForPipeline\s*\(')
            .allMatches(source)
            .length,
        1,
      );
      expect(
        RegExp(r'Future<bool>\s+_sendAiMessageLegacyCore\s*\(')
            .allMatches(source)
            .length,
        1,
      );
    });

    test('selector owns cutover and core owns terminal', () {
      final source = File(
        'lib/providers/app_provider.dart',
      ).readAsStringSync();
      final selector = _body(source, 'sendAiMessage');
      final core = _body(
        source,
        '_sendAiMessageLegacyCore',
      );

      expect(
        selector,
        contains('phase3kShouldAttemptBufferedCutover'),
      );
      expect(
        selector,
        contains('AiProviderEffectPolicy.legacy'),
      );
      expect(
        core,
        isNot(contains('phase3kShouldAttemptBufferedCutover')),
      );
      expect(core, contains('AiFinalizationTransaction'));
    });

    test('pipeline port bypasses public selector', () {
      final source = File(
        'lib/services/ai_pipeline/'
        'app_provider_ai_response_pipeline.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('provider.sendAiMessageForPipeline('),
      );
      expect(
        source,
        isNot(contains('provider.sendAiMessage(')),
      );
    });

    test('buffered bridge only forwards internal callbacks', () {
      final source = File(
        'lib/providers/app_provider.dart',
      ).readAsStringSync();
      final bridge = _body(
        source,
        'sendAiMessageForPipeline',
      );

      expect(
        bridge,
        contains(
          'AiProviderEffectPolicy.bufferedPipeline',
        ),
      );
      expect(
        bridge,
        isNot(contains('phase3kShouldAttemptBufferedCutover')),
      );
      expect(bridge, isNot(contains('onChunk(')));
      expect(bridge, isNot(contains('onDone(')));
      expect(bridge, isNot(contains('onError(')));
    });

    test('pipeline port changes only the delegated owner', () {
      final source = File(
        'lib/services/ai_pipeline/'
        'app_provider_ai_response_pipeline.dart',
      ).readAsStringSync();

      expect(
        RegExp(r'provider\.sendAiMessageForPipeline\s*\(')
            .allMatches(source)
            .length,
        1,
      );
      expect(
        RegExp(r'provider\.sendAiMessage\s*\(')
            .allMatches(source)
            .length,
        0,
      );
    });

    test('feature flag stays default off', () {
      final source = File(
        'lib/providers/app_provider.dart',
      ).readAsStringSync();
      expect(
        source,
        contains(
          'const PlantaoBufferedCutoverController.disabled()',
        ),
      );
    });
  });
}

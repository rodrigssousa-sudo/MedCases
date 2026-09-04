import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String compactWhitespace(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

void main() {
  group('Plantão visible input external-tool intent contract', () {
    late String provider;
    late String engine;
    late String compactProvider;
    late String compactEngine;

    setUpAll(() {
      provider = File('lib/providers/app_provider.dart').readAsStringSync();
      engine = File('lib/services/external_tool_link_engine.dart')
          .readAsStringSync();
      compactProvider = compactWhitespace(provider);
      compactEngine = compactWhitespace(engine);
    });

    test('preserves the visible and model payload separation owner', () {
      expect(
        compactProvider,
        contains(
          'final persistedUserInput = '
          'visibleInputCandidate.isNotEmpty '
          '? visibleInputCandidate : input;',
        ),
      );
    });

    test('GPT finalizer declares an explicit visible-input parameter', () {
      expect(
        RegExp(
          r'Future<void>\s+_finalizeGptSuccessfulRequest\(\{'
          r'[\s\S]*?required String input,'
          r'\s*required String visibleUserInput,'
          r'\s*(?:String\? userDisplayText,\s*)?'
          r'required bool longResponse,',
        ).hasMatch(provider),
        isTrue,
      );
    });

    test('GPT finalizer tool gate consumes only visible input', () {
      expect(
        RegExp(
          r'ExternalToolLinkEngine\.build\('
          r'[\s\S]*?lastUserMessage:\s*visibleUserInput,',
        ).hasMatch(provider),
        isTrue,
      );
      expect(
        RegExp(
          r'lastUserMessage:\s*persistedUserInput,',
        ).allMatches(provider).length,
        1,
      );
    });

    test('both GPT productive callsites thread persisted visible input', () {
      expect(
        RegExp(
          r'visibleUserInput:\s*persistedUserInput,',
        ).allMatches(provider).length,
        2,
      );
    });

    test('canonical external-tool decision uses visible input', () {
      expect(
        RegExp(
          r'ExternalToolLinkEngine\.resolveDecision\('
          r'\s*thisRequestId,\s*persistedUserInput,?\s*\)',
        ).hasMatch(provider),
        isTrue,
      );
      expect(
        RegExp(
          r'ExternalToolLinkEngine\.resolveDecision\('
          r'\s*thisRequestId,\s*input,?\s*\)',
        ).hasMatch(provider),
        isFalse,
      );
    });

    test('complete clinical input remains available to the model', () {
      expect(
        RegExp(r'userQuery:\s*input,').hasMatch(provider),
        isTrue,
      );
      expect(compactProvider, contains('persistedUserInput'));
    });

    test('engine keeps its sovereign visible-message embargo', () {
      expect(
        RegExp(
          r'resolveExternalToolIntent\(\s*lastUserMessage\s*\)',
        ).hasMatch(engine),
        isTrue,
      );
      expect(compactEngine, contains('if (!intentAllowed)'));
      expect(compactEngine, contains('return null;'));
    });
  });
}

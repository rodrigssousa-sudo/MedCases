import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão visible/model payload separation contract', () {
    late String aiScreen;
    late String appProvider;

    setUpAll(() {
      aiScreen = File(
        'lib/screens/ai_screen.dart',
      ).readAsStringSync();

      appProvider = File(
        'lib/providers/app_provider.dart',
      ).readAsStringSync();
    });

    test('keeps the visible bubble bound to the short action', () {
      expect(
        RegExp(
          r"_messages\.add\(\s*_ChatMsg\(\s*role:\s*'user',\s*"
          r"text:\s*trimmed,\s*userDisplayText:\s*"
          r"normalizedUserDisplayText\.isNotEmpty",
          multiLine: true,
        ).hasMatch(aiScreen),
        isTrue,
      );
      expect(
        RegExp(
          r'await\s+p\.sendAiMessage\(\s*providerInput\s*,'
          r'\s*visibleUserInput:\s*trimmed\s*,',
        ).hasMatch(aiScreen),
        isTrue,
      );
    });

    test('keeps the complete case anchor in the model payload', () {
      expect(
        aiScreen,
        contains('_bindPlantaoCaseAnchorForButton(trimmed)'),
      );
      expect(
        aiScreen,
        contains('CONTEXTO CLÍNICO OBRIGATÓRIO DESTE MESMO CASO'),
      );
      expect(
        aiScreen,
        contains('Não substitua o caso por uma orientação genérica'),
      );
    });

    test('declares the optional visible payload at the boundary', () {
      expect(
        RegExp(
          r'String\?\s+visibleUserInput\s*,',
        ).hasMatch(appProvider),
        isTrue,
      );
      expect(
        RegExp(
          r'final\s+visibleInputCandidate\s*='
          r'\s*visibleUserInput\?\.trim\(\)\s*\?\?\s*'
          r"''\s*;",
        ).hasMatch(appProvider),
        isTrue,
      );
      expect(
        RegExp(
          r'final\s+persistedUserInput\s*='
          r'\s*visibleInputCandidate\.isNotEmpty'
          r'\s*\?\s*visibleInputCandidate'
          r'\s*:\s*input\s*;',
        ).hasMatch(appProvider),
        isTrue,
      );
    });

    test('falls back to original input for unaffected callers', () {
      expect(
        RegExp(
          r'visibleInputCandidate\.isNotEmpty'
          r'\s*\?\s*visibleInputCandidate'
          r'\s*:\s*input\s*;',
        ).hasMatch(appProvider),
        isTrue,
      );
    });

    test('writes visible text into provider history', () {
      expect(
        RegExp(
          r"\{\s*'role'\s*:\s*'user'\s*,"
          r"\s*'content'\s*:\s*persistedUserInput\s*\}",
        ).allMatches(appProvider).length,
        9,
      );
    });

    test('writes visible text into canonical persistence', () {
      expect(
        RegExp(
          r'\buserInput\s*:\s*persistedUserInput\s*,',
        ).allMatches(appProvider).length,
        5,
      );
    });

    test('preserves complete input for clinical routing', () {
      expect(
        RegExp(r'\buserQuery\s*:\s*input\b').hasMatch(appProvider),
        isTrue,
      );
      expect(
        RegExp(r'\buserMessage\s*:\s*input\b').hasMatch(appProvider),
        isTrue,
      );
      expect(
        RegExp(
          r'AiSmartRouter\.detectTaskLabel\(\s*input\b',
        ).hasMatch(appProvider),
        isTrue,
      );
    });

    test('keeps canonical restore input with optional display provenance', () {
      expect(
        aiScreen,
        contains("final userInput = (exchange['userInput'] as String?) ?? '';"),
      );
      expect(
        RegExp(
          r"_ChatMsg\(\s*role:\s*'user'\s*,"
          r"\s*text:\s*userInput\s*,"
          r"\s*userDisplayText:\s*userDisplayText\?\.isNotEmpty"
          r"\s*==\s*true",
          multiLine: true,
        ).hasMatch(aiScreen),
        isTrue,
      );
    });
  });
}

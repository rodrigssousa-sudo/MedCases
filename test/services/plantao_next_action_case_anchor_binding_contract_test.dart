import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PHASE3I-J2D1 V2 Plantão case-anchor binding', () {
    late String screen;

    setUpAll(() {
      screen = File('lib/screens/ai_screen.dart').readAsStringSync();
    });

    test('declares dedicated binder', () {
      expect(
        screen,
        contains('String _bindPlantaoCaseAnchorForButton(String actionText)'),
      );
      expect(
        screen,
        contains('PHASE3I-J2D1: bind canonical user case anchor'),
      );
    });

    test('uses only prior user messages', () {
      expect(screen, contains("if (message.role != 'user') continue;"));
      expect(screen, contains('canonicalUserCase = candidate;'));
      expect(
        screen,
        contains(
          'if (candidate.isEmpty || candidate == normalizedAction) continue;',
        ),
      );
    });

    test('binding is restricted to Plantão button actions', () {
      expect(
        screen,
        contains('final providerInput = fromButton && !_longResponse'),
      );
      expect(
        screen,
        contains('? _bindPlantaoCaseAnchorForButton(trimmed)'),
      );
    });

    test('visible user bubble stays short', () {
      expect(
        RegExp(
          r"_messages\.add\(\s*_ChatMsg\(\s*role:\s*'user',\s*"
          r"text:\s*trimmed,\s*userDisplayText:\s*"
          r"normalizedUserDisplayText\.isNotEmpty",
          multiLine: true,
        ).hasMatch(screen),
        isTrue,
      );
      expect(
        screen,
        contains('await p.sendAiMessage(\n        providerInput,'),
      );
    });

    test('provider input contains explicit case-preservation contract', () {
      expect(
        screen,
        contains('CONTEXTO CLÍNICO OBRIGATÓRIO DESTE MESMO CASO'),
      );
      expect(
        screen,
        contains('Não substitua o caso por uma orientação genérica.'),
      );
    });

    test('J2B1 and J2B2 remain present', () {
      expect(
        screen,
        contains('PHASE3I-J2B1: terminal ownership reached'),
      );

      final provider =
          File('lib/providers/app_provider.dart').readAsStringSync();
      expect(
        provider,
        contains('PHASE3I-J2B2: rehydrate button continuation context'),
      );
    });
  });
}

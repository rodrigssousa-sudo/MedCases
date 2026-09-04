import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/chat_message.dart';

void main() {
  group('Plantão next-action display-only provenance V1-B-R1', () {
    test('ChatMessage separates canonical prompt from short visual label', () {
      final message = ChatMessage(
        role: 'user',
        text:
            'IAM/SCA ya en etapa terapéutica: detalla estratificación de riesgo, '
            'estrategia invasiva, monitorización y complicaciones.',
        userDisplayText: 'Estratificación de riesgo y manejo',
      );

      expect(message.text, startsWith('IAM/SCA ya en etapa terapéutica:'));
      expect(message.userDisplayText, 'Estratificación de riesgo y manejo');

      final changed = message.copyWith(
        text: '${message.text} Mantener contexto clínico.',
      );
      expect(changed.userDisplayText, 'Estratificación de riesgo y manejo');

      final cleared = changed.copyWith(clearUserDisplayText: true);
      expect(cleared.userDisplayText, isNull);
    });

    test('button callback carries prompt and label independently', () {
      final source = File(
        'lib/screens/ai/widgets/action_buttons_row.dart',
      ).readAsStringSync();

      expect(source, contains('required String visibleLabel,'));
      expect(source, contains('visibleLabel: aiLabel,'));
      expect(
        source,
        contains('hasStudyNext ? effectiveStudyPrompt : action.promptToSend'),
      );
    });

    test(
      'AiScreen keeps canonical text for provider/edit and short display',
      () {
        final source = File('lib/screens/ai_screen.dart').readAsStringSync();

        expect(source, contains('text: trimmed,'));
        expect(source, contains('visibleUserInput: trimmed,'));
        expect(
          source,
          contains('userDisplayText: normalizedUserDisplayText.isNotEmpty'),
        );
        expect(source, contains('userDisplayText: visibleLabel,'));
        expect(source, contains("map['userDisplayText']"));
        expect(source, contains('userDisplayText: exchange.userDisplayText,'));
        expect(
          source,
          contains(
            "final displayCandidate = msg.userDisplayText?.trim() ?? '';",
          ),
        );
        expect(
          RegExp(
            r'UserMessageDisplayPolicy\.visibleText\(\s*msg\.text,\s*\)',
            multiLine: true,
          ).hasMatch(source),
          isTrue,
        );
        expect(source, contains('editText: msg.text,'));
        expect(source, contains('onCopy: () => _copyMsg(userVisibleText)'));
      },
    );

    test('provider display provenance never becomes canonical routing input', () {
      final source = File(
        'lib/providers/app_provider.dart',
      ).readAsStringSync();

      final canonicalPersistedInput = RegExp(
        r'final\s+persistedUserInput\s*=\s*'
        r'visibleInputCandidate\.isNotEmpty\s*\?\s*'
        r'visibleInputCandidate\s*:\s*input\s*;',
        multiLine: true,
      );
      expect(canonicalPersistedInput.hasMatch(source), isTrue);

      expect(
        source,
        contains(
          "final persistedUserDisplayText = userDisplayText?.trim() ?? '';",
        ),
      );

      final canonicalDecisionUsesPersistedInput = RegExp(
        r'ExternalToolLinkEngine\.resolveDecision\(\s*'
        r'thisRequestId\s*,\s*'
        r'persistedUserInput\s*,?\s*\)',
        multiLine: true,
      );
      expect(canonicalDecisionUsesPersistedInput.hasMatch(source), isTrue);

      final displayTextLeaksIntoCanonicalDecision = RegExp(
        r'ExternalToolLinkEngine\.resolveDecision\([^)]*'
        r'persistedUserDisplayText',
        multiLine: true,
      );
      expect(displayTextLeaksIntoCanonicalDecision.hasMatch(source), isFalse);

      expect(source, contains('String? userDisplayText,'));
      expect(source, contains('userDisplayTextFull:'));
    });

    test('typed pipeline bridge remains outside display-only provenance', () {
      final source = File('lib/providers/app_provider.dart').readAsStringSync();

      final start = source.indexOf('Future<bool> sendAiMessageForPipeline(');
      final end = source.indexOf(
        'Future<bool> _sendAiMessageLegacyCore(',
        start,
      );

      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));

      final bridge = source.substring(start, end);
      expect(bridge, isNot(contains('userDisplayText')));
    });

    test('Firestore keeps canonical userInput and optional display field', () {
      final source = File(
        'lib/services/firestore_service.dart',
      ).readAsStringSync();

      expect(source, contains("'userInput': userInputFull"));
      expect(
        source,
        contains(
          "exchangeData['userDisplayText'] = normalizedUserDisplayText;",
        ),
      );
      expect(source, contains('if (normalizedUserDisplayText.isNotEmpty)'));
      expect(source, contains("'schemaVersion': 2"));
    });

    test('Preguntas-chave legacy display fallback remains intact', () {
      final source = File(
        'lib/screens/ai/widgets/user_message_display_policy.dart',
      ).readAsStringSync();

      expect(source, contains("return 'Preguntas clave';"));
      expect(source, contains("return 'Perguntas-chave';"));
      expect(source, contains('return rawText;'));
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String ai;
  late String home;
  late String palette;
  late String mplus;
  late String modes;
  late String composer;
  late String bubble;

  setUpAll(() {
    ai = File(
      'lib/screens/ai_screen.dart',
    ).readAsStringSync();

    home = File(
      'lib/home_v2/components/chat/'
      'inline_chat_view.dart',
    ).readAsStringSync();

    palette = File(
      'lib/home_v2/theme/'
      'home_v2_palette.dart',
    ).readAsStringSync();

    mplus = File(
      'lib/screens/ai/widgets/'
      'mobile_ai_action_bar.dart',
    ).readAsStringSync();

    modes = File(
      'lib/screens/ai/widgets/'
      'response_mode_toggle.dart',
    ).readAsStringSync();

    composer = File(
      'lib/screens/ai/widgets/'
      'prompt_composer.dart',
    ).readAsStringSync();

    bubble = File(
      'lib/screens/ai/widgets/'
      'ai_bubble.dart',
    ).readAsStringSync();
  });

  group(
    'AI-VIS-B.2-R2 — saudação da aba IA',
    () {
      test(
        'mantém geração canônica PT e ES',
        () {
          expect(
            ai,
            contains(
              'Sou o MedCases IA. '
              'Como posso te ajudar hoje?',
            ),
          );

          expect(
            ai,
            contains(
              'Soy MedCases IA. '
              '¿Cómo puedo ayudarte hoy?',
            ),
          );

          expect(
            ai,
            contains(
              '_buildGreeting(',
            ),
          );

          expect(
            ai,
            contains(
              '_buildGreeting(p.userName, p.lang)',
            ),
          );

          expect(
            ai,
            contains(
              'void _injectGreeting()',
            ),
          );
        },
      );

      test(
        'detecta somente a primeira mensagem AI',
        () {
          expect(
            ai,
            contains(
              'bool _isOpeningHomeGreeting('
              'int index, _ChatMsg msg)',
            ),
          );

          expect(
            ai,
            contains(
              "if (index != 0 || "
              "msg.role != 'ai')",
            ),
          );

          expect(
            ai,
            contains(
              'if (_isOpeningHomeGreeting(i, msg))',
            ),
          );
        },
      );

      test(
        'projeção visual ocorre antes da AiBubble',
        () {
          final userBranch = ai.indexOf(
            "if (msg.role == 'user')",
          );

          final greetingBranch = ai.indexOf(
            'if (_isOpeningHomeGreeting(i, msg))',
            userBranch,
          );

          final marker = ai.indexOf(
            '// ── AI message — '
            'detectar fármaco en texto',
            greetingBranch,
          );

          final bubbleIndex = ai.indexOf(
            'AiBubble(',
            marker,
          );

          expect(
            userBranch,
            greaterThanOrEqualTo(0),
          );

          expect(
            greetingBranch,
            greaterThan(userBranch),
          );

          expect(
            marker,
            greaterThan(greetingBranch),
          );

          expect(
            bubbleIndex,
            greaterThan(marker),
          );

          final projection = ai.substring(
            greetingBranch,
            marker,
          );

          expect(
            projection,
            contains('_AiHomeGreeting('),
          );

          expect(
            projection,
            contains('text: msg.text'),
          );

          expect(
            projection,
            contains(
              "ValueKey('msg_\${msg.id}')",
            ),
          );
        },
      );

      test(
        'usa identidade visual oficial da Home',
        () {
          final start = ai.indexOf(
            'class _AiHomeGreeting '
            'extends StatelessWidget',
          );

          expect(
            start,
            greaterThanOrEqualTo(0),
          );

          final greeting = ai.substring(start);

          for (final token in const [
            'HomeV2Palette.resolve(dark)',
            r"text.split('\n\n').first.trim()",
            "'Descreva o caso ou a dúvida clínica.'",
            "'Describe el caso o la duda clínica.'",
            'maxWidth: 560',
            'fontSize: 22',
            'fontSize: 12.5',
            'palette.textPrimary',
            'palette.textSecondary',
            'textAlign: TextAlign.center',
            'CrossAxisAlignment.center',
          ]) {
            expect(
              greeting,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'espelha o contrato homologado da Home',
        () {
          expect(
            home,
            contains('fontSize: 22'),
          );

          expect(
            home,
            contains(
              "'Descreva o caso ou a dúvida clínica.'",
            ),
          );

          expect(
            home,
            contains(
              "'Describe el caso o la duda clínica.'",
            ),
          );

          expect(
            palette,
            contains(
              'static HomeV2Palette resolve(bool dark)',
            ),
          );
        },
      );

      test(
        'preserva componentes funcionais',
        () {
          expect(
            mplus,
            contains('class MobileAiActionBar'),
          );

          expect(
            modes,
            contains('class ResponseModeToggle'),
          );

          expect(
            composer,
            contains('class PromptComposer'),
          );

          expect(
            bubble,
            contains('class AiBubble'),
          );

          for (final token in const [
            'MobileAiActionBar(',
            'ResponseModeToggle(',
            'PromptComposer(',
            'AiBubble(',
            '_toggleStt',
            '_toggleTts',
            '_streamingTextNotifier',
            'pendingQuery',
            'pendingHistory',
            '_chatHistory',
          ]) {
            expect(
              ai,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'não cria infraestrutura paralela',
        () {
          final start = ai.indexOf(
            'class _AiHomeGreeting '
            'extends StatelessWidget',
          );

          final greeting = ai.substring(start);

          for (final forbidden in const [
            'ChangeNotifier',
            'Provider<',
            'StreamController',
            'TextEditingController',
            'SharedPreferences',
            'FirebaseFirestore',
            'SpeechToText',
            'SttHelper',
          ]) {
            expect(
              greeting,
              isNot(contains(forbidden)),
              reason: forbidden,
            );
          }
        },
      );
    },
  );
}

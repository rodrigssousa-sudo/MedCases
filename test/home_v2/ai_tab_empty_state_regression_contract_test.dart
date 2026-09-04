import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String region(
  String source,
  String startMarker,
  String endMarker,
) {
  final start = source.indexOf(startMarker);
  final end = source.indexOf(endMarker, start);

  expect(
    start,
    greaterThanOrEqualTo(0),
    reason: startMarker,
  );

  expect(
    end,
    greaterThan(start),
    reason: endMarker,
  );

  return source.substring(start, end);
}

void main() {
  late String ai;
  late String suggestions;
  late String ttl;

  setUpAll(() {
    ai = File(
      'lib/screens/ai_screen.dart',
    ).readAsStringSync();

    suggestions = File(
      'lib/screens/ai/widgets/'
      'suggestion_carousel.dart',
    ).readAsStringSync();

    ttl = region(
      ai,
      'Future<void> _checkScreenTtl() async {',
      '/// Atualiza o timestamp de última atividade',
    );
  });

  group(
    'AI-VIS-B.5-R5 — estado vazio canônico',
    () {
      test(
        'AiScreen não projeta sugestões clínicas legadas',
        () {
          for (final forbidden in const [
            "import 'ai/widgets/"
                "suggestion_carousel.dart';",
            'bool get _showSuggestions',
            'void _insertSuggestion(',
            'SuggestionCarousel(',
            'onTap: _insertSuggestion',
          ]) {
            expect(
              ai,
              isNot(contains(forbidden)),
              reason: forbidden,
            );
          }
        },
      );

      test(
        'arquivo legado permanece preservado para classificação',
        () {
          expect(
            suggestions,
            contains(
              'class SuggestionCarousel '
              'extends StatelessWidget',
            ),
          );

          for (final label in const [
            'IAM / dolor torácico',
            'Choque + hipotensión',
            'Anafilaxia',
          ]) {
            expect(
              suggestions,
              contains(label),
              reason: label,
            );
          }
        },
      );

      test(
        'TTL reinjeta saudação após limpar o contexto',
        () {
          for (final token in const [
            '_messages.clear();',
            '_greetingDone = false;',
            'p.clearAiHistory();',
            'WidgetsBinding.instance'
                '.addPostFrameCallback((_) {',
            'if (!mounted) return;',
            '_injectGreeting();',
          ]) {
            expect(
              ttl,
              contains(token),
              reason: token,
            );
          }

          final clearMessages = ttl.indexOf('_messages.clear();');

          final clearHistory = ttl.indexOf('p.clearAiHistory();');

          final callback = ttl.indexOf(
            'WidgetsBinding.instance'
            '.addPostFrameCallback((_) {',
          );

          final inject = ttl.indexOf('_injectGreeting();');

          expect(
            clearHistory,
            greaterThan(clearMessages),
          );

          expect(
            callback,
            greaterThan(clearHistory),
          );

          expect(
            inject,
            greaterThan(callback),
          );
        },
      );

      test(
        'injeção inicial da saudação permanece intacta',
        () {
          expect(
            ai,
            contains(
              'WidgetsBinding.instance'
              '.addPostFrameCallback((_) {\n'
              '      _injectGreeting();',
            ),
          );

          expect(
            ai,
            contains(
              'void _injectGreeting()',
            ),
          );

          final injection = region(
            ai,
            'void _injectGreeting()',
            'double _lastScrollOffset',
          );

          for (final token in const [
            "_messages",
            "role: 'ai'",
            "_buildGreeting(p.userName, p.lang)",
          ]) {
            expect(
              injection,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'renderer homologado da saudação permanece ativo',
        () {
          for (final token in const [
            'bool _isOpeningHomeGreeting(',
            'if (_isOpeningHomeGreeting(i, msg))',
            'if (hasConversation)',
            'greeting_hidden_after_start',
            'child: _AiHomeGreeting(',
            'compact: false',
            'animate: false',
            'class _AiHomeGreeting '
                'extends StatelessWidget',
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
        'novo chat e limpeza continuam disponíveis',
        () {
          for (final token in const [
            'void _clearChat()',
            'void _startNewChat({bool preserveConfirmedMode = false})',
            '_buildGreeting(p.userName, p.lang)',
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
        'seletor Estudo e Plantão permanece funcional',
        () {
          for (final token in const [
            'ResponseModeToggle(',
            'value: _longResponse',
            'onChanged: _commitResponseMode',
            'void _commitResponseMode(',
            'void _openResponseModeSelector()',
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
        'correção não cria infraestrutura paralela',
        () {
          for (final forbidden in const [
            'class AiEmptyStateController',
            'class GreetingProvider',
            'class EmptyStateProvider',
            'StreamController',
            'FirebaseFirestore',
          ]) {
            expect(
              ttl,
              isNot(contains(forbidden)),
              reason: forbidden,
            );
          }
        },
      );
    },
  );
}

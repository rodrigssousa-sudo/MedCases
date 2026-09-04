import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classSlice(String source, String className) {
  final matches = RegExp(
    '\\bclass\\s+${RegExp.escape(className)}\\b',
  ).allMatches(source).toList();
  expect(matches.length, 1, reason: 'Classe deve ser única: $className');

  final start = matches.single.start;
  final brace = source.indexOf('{', matches.single.end);
  expect(brace, greaterThanOrEqualTo(0));

  var depth = 0;
  var quote = '';
  var escaped = false;
  var lineComment = false;
  var blockComment = false;

  for (var i = brace; i < source.length; i++) {
    final c = source[i];
    final n = i + 1 < source.length ? source[i + 1] : '';

    if (lineComment) {
      if (c == '\n') lineComment = false;
      continue;
    }
    if (blockComment) {
      if (c == '*' && n == '/') {
        blockComment = false;
        i++;
      }
      continue;
    }
    if (quote.isNotEmpty) {
      if (escaped) {
        escaped = false;
      } else if (c == r'\') {
        escaped = true;
      } else if (c == quote) {
        quote = '';
      }
      continue;
    }
    if (c == '/' && n == '/') {
      lineComment = true;
      i++;
      continue;
    }
    if (c == '/' && n == '*') {
      blockComment = true;
      i++;
      continue;
    }
    if (c == "'" || c == '"') {
      quote = c;
      continue;
    }

    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(start, i + 1);
      }
    }
  }

  fail('Classe sem fechamento: $className');
}

String markerSlice(String source, String begin, String end) {
  final a = source.indexOf(begin);
  final b = source.indexOf(end, a + begin.length);
  expect(a, greaterThanOrEqualTo(0), reason: begin);
  expect(b, greaterThan(a), reason: end);
  return source.substring(a, b + end.length);
}

void main() {
  late String home;
  late String mainSource;
  late String tools;
  late String homeV2;

  setUpAll(() {
    home = File('lib/screens/home_screen.dart').readAsStringSync();
    mainSource = File('lib/main.dart').readAsStringSync();
    tools = File('lib/screens/tools_screen.dart').readAsStringSync();
    homeV2 = File('lib/home_v2/home_screen_v2.dart').readAsStringSync();
  });

  group('Pediatria MainShell floating footer V1-B-R0', () {
    test(
      'PediatricsTabContent e owner clínico permanecem intactos na arquitetura',
      () {
        expect(
          RegExp(
            r'class\s+PediatricsTabContent\s+extends\s+StatefulWidget',
          ).allMatches(tools).length,
          1,
        );
        expect(
          RegExp(
            r'class\s+_PediatricsTabContentState\b',
          ).allMatches(tools).length,
          1,
        );
        expect(home, contains('const Expanded(child: PediatricsTabContent())'));
      },
    );

    test('workspace público só delega ao shell pediátrico existente', () {
      final workspace = classSlice(home, 'PediatricsMainShellWorkspace');
      expect(workspace, contains('required this.onBack'));
      expect(workspace, contains('final VoidCallback onBack;'));
      expect(workspace, contains('_PediatricsShell(onBack: onBack)'));
      expect(workspace, isNot(contains('_FloatingFooter(')));
      expect(workspace, isNot(contains('bottomNavigationBar:')));
    });

    test('topbar pediátrica preserva visual e aceita retorno do MainShell', () {
      final shell = classSlice(home, '_PediatricsShell');
      expect(shell, contains('MEDCASES_PEDIATRIA_HOME_TOPBAR_V1_B_R0'));
      expect(shell, isNot(contains('appBar: PreferredSize(')));
      expect(shell, contains('height: 48'));
      expect(shell, contains('height: topPad + 48'));
      expect(shell, contains('View.of(context).padding.top'));
      expect(shell, contains('BackdropFilter('));
      expect(shell, contains('fontSize: 16'));
      expect(shell, contains('const Expanded(child: PediatricsTabContent())'));
      expect(shell, contains('const _PediatricsShell({this.onBack});'));
      expect(shell, contains('final VoidCallback? onBack;'));
      expect(shell, contains('onTap: onBack ??'));
      expect(
        shell,
        contains('() => Navigator.of(context).pop(),'),
      );
      expect(shell, isNot(contains('_FloatingFooter(')));
      expect(shell, isNot(contains('bottomNavigationBar:')));
    });

    test('card Pediatria da Home usa tab 8 sem Navigator próprio', () {
      final wrapper = classSlice(home, 'HomePatientPediatricsRow');
      final route = markerSlice(
        wrapper,
        'PEDIATRIA_MAIN_SHELL_FOOTER_V1_B_R0_ROUTE_BEGIN',
        'PEDIATRIA_MAIN_SHELL_FOOTER_V1_B_R0_ROUTE_END',
      );
      expect(route, contains('onTabChange(8);'));
      expect(route, isNot(contains('Navigator.')));
      expect(route, isNot(contains('_PediatricsShell(')));
      expect(wrapper, contains('final ValueChanged<int> onTabChange;'));
      expect(homeV2, contains('onTabChange: onTabChange,'));
    });

    test('MainShell monta Pediatria como workspace interno tab 8', () {
      expect(
        mainSource,
        contains(
          "import 'screens/home_screen.dart' show PediatricsMainShellWorkspace;",
        ),
      );
      expect(
        mainSource,
        contains('PediatricsMainShellWorkspace(onBack: _closePediatrics)'),
      );
      expect(
        mainSource,
        contains('void _closePediatrics() => _onTabChange(0);'),
      );
      expect(mainSource, contains('PEDIATRIA_MAIN_SHELL_FOOTER_V1_B_R0_TAB_8'));
    });

    test('footer global continua com owner único no MainShell', () {
      expect(
        RegExp(
          r'class\s+_FloatingFooter\s+extends\s+StatefulWidget',
        ).allMatches(mainSource).length,
        1,
      );
      expect(
        RegExp(r'return\s+_FloatingFooter\s*\(').hasMatch(mainSource),
        isTrue,
      );
      expect(mainSource, contains('MainShell.navScrollingDown'));
      expect(mainSource, contains('_LegalGlassShelf('));
      expect(home, isNot(contains('class _FloatingFooter')));
      expect(tools, isNot(contains('class _FloatingFooter')));
    });

    test('iPad mantém workspace não IA e IA persistente', () {
      expect(mainSource, contains('int _lastNonAiWorkspaceTab = 0;'));
      expect(mainSource, contains('_lastNonAiWorkspaceTab = t;'));
      expect(
        mainSource,
        contains('final bool showPersistentAiSplit = width >= 1024;'),
      );
      expect(mainSource, contains('_staticScreens[leftPaneIndex]'));
      expect(mainSource, contains('_staticScreens[2]'));
    });
  });
}

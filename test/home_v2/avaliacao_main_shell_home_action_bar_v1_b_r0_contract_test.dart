import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final start = RegExp(
    '^class\\s+${RegExp.escape(className)}\\b',
    multiLine: true,
  ).firstMatch(source);
  if (start == null) {
    throw StateError('class missing: $className');
  }

  final next = RegExp(
    r'^class\s+[A-Za-z0-9_]+\b',
    multiLine: true,
  ).firstMatch(source.substring(start.end));

  final end = next == null ? source.length : start.end + next.start;
  return source.substring(start.start, end);
}

void main() {
  late String mainSource;
  late String home;
  late String homeV2;
  late String assessment;

  setUpAll(() {
    mainSource = File('lib/main.dart').readAsStringSync();
    home = File('lib/screens/home_screen.dart').readAsStringSync();
    homeV2 = File('lib/home_v2/home_screen_v2.dart').readAsStringSync();
    assessment = File('lib/screens/avaliacao_screen.dart').readAsStringSync();
  });

  group('Avaliação MainShell + Home action bar V1-B-R0', () {
    test('Home Assessment enters MainShell tab 12', () {
      final owner = classBlock(home, '_HomeAssessmentNotesTimerCardState');

      expect(owner, contains('widget.onTabChange(12);'));
      expect(owner, isNot(contains('HomeScreen._openAvaliacao(context);')));
      expect(homeV2, contains('HomeAssessmentNotesTimerCard('));
      expect(homeV2, contains('onTabChange: onTabChange,'));
    });

    test('tab 12 reuses the single global FloatingFooter owner', () {
      expect(
        RegExp(
          r'^class\s+_FloatingFooter\s+extends\s+StatefulWidget\b',
          multiLine: true,
        ).allMatches(mainSource).length,
        1,
      );
      expect(
        mainSource,
        contains('AVALIACAO_MAIN_SHELL_FOOTER_V1_B_R0_TAB_12'),
      );
      expect(mainSource, contains('embeddedInMainShell: true'));
      expect(mainSource, contains('onBack: _closeAvaliacaoMainShell'));
      expect(
        mainSource,
        contains(
          'void _closeAvaliacaoMainShell() => _onTabChange(0);',
        ),
      );
      expect(assessment, isNot(contains('_FloatingFooter(')));
      expect(assessment, isNot(contains('bottomNavigationBar:')));
    });

    test('mobile safe-top and keyboard footer rules include tab 12', () {
      expect(
        mainSource,
        contains('removeTop: !isHome && _tab != 11 && _tab != 12,'),
      );
      expect(
        RegExp(
          r'_tab\s*==\s*11\s*\|\|\s*_tab\s*==\s*12\)\s*\?\s*0',
        ).hasMatch(mainSource),
        isTrue,
      );
      expect(
        mainSource,
        contains('final assessmentKeyboardOpen = _tab == 12 &&'),
      );
      expect(mainSource, contains('assessmentKeyboardOpen;'));
    });

    test('Avaliação preserves legacy route and gains embedded back contract',
        () {
      expect(assessment, contains('final bool embeddedInMainShell;'));
      expect(assessment, contains('final VoidCallback? onBack;'));
      expect(
        assessment,
        contains('this.embeddedInMainShell = false'),
      );
      expect(
        assessment,
        contains('void _exitAvaliacao(BuildContext ctx)'),
      );
      expect(
        assessment,
        contains(
          'resizeToAvoidBottomInset: !widget.embeddedInMainShell',
        ),
      );
      expect(
        assessment,
        contains('onBack: () => _confirmBack(context, p),'),
      );
    });

    test('bottom actions clear the global footer only on compact MainShell',
        () {
      final bottom = classBlock(assessment, '_BottomBar');

      expect(bottom, contains('final bool reserveGlobalActionBar;'));
      expect(bottom, contains('112.0 + safeBottom'));
      expect(
        bottom,
        contains('const EdgeInsets.fromLTRB(8, 5, 8, 28)'),
      );
      expect(
        assessment,
        contains('MediaQuery.sizeOf(context).width < 768'),
      );
      expect(
        assessment,
        contains('MediaQuery.viewInsetsOf(context).bottom == 0'),
      );
    });

    test('the existing Home Liquid Glass action bar itself is untouched', () {
      final footer = classBlock(mainSource, '_FloatingFooterState');

      expect(
        footer,
        contains('MEDCASES_GLOBAL_ACTION_BAR_TRUE_LIQUID_GLASS'),
      );
      expect(
        footer,
        contains('ImageFilter.blur(sigmaX: 16, sigmaY: 16)'),
      );
      expect(footer, contains('static const _barHeightFull = 50.0;'));
      expect(footer, contains('static const _barHeightShrunk = 38.0;'));
    });
  });
}

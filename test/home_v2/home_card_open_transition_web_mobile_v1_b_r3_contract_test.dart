import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

String blockForClass(String source, String className) {
  final marker = RegExp(
    '^\\s*class\\s+${RegExp.escape(className)}\\b[^\\{]*\\{',
    multiLine: true,
  ).firstMatch(source);

  expect(marker, isNotNull, reason: 'class $className must exist');

  final start = marker!.start;
  final open = source.indexOf('{', start);
  var depth = 0;
  var quote = '';
  var escaped = false;
  var lineComment = false;
  var blockComment = false;

  for (var i = open; i < source.length; i++) {
    final c = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';

    if (lineComment) {
      if (c == '\n') lineComment = false;
      continue;
    }

    if (blockComment) {
      if (c == '*' && next == '/') {
        blockComment = false;
        i++;
      }
      continue;
    }

    if (quote.isNotEmpty) {
      if (escaped) {
        escaped = false;
      } else if (c == '\\') {
        escaped = true;
      } else if (c == quote) {
        quote = '';
      }
      continue;
    }

    if (c == '/' && next == '/') {
      lineComment = true;
      i++;
      continue;
    }

    if (c == '/' && next == '*') {
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

  fail('unbalanced class $className');
}

void main() {
  group('Home card opening transition — Web + mobile V1-B-R3', () {
    late String helper;
    late String main;
    late String home;
    late String homeV2;
    late String guideGrid;

    setUpAll(() {
      helper = read(
        'lib/home_v2/components/navigation/home_card_transition.dart',
      );
      main = read('lib/main.dart');
      home = read('lib/screens/home_screen.dart');
      homeV2 = read('lib/home_v2/home_screen_v2.dart');
      guideGrid = read(
        'lib/home_v2/components/home_web_latest_guides_grid.dart',
      );
    });

    test('canonical transition is bottom-up 240ms with 220ms route reverse',
        () {
      expect(
        helper,
        contains(
          'MEDCASES_HOME_CARD_OPEN_TRANSITION_UNIFICATION_WEB_MOBILE_V1_B_R3',
        ),
      );
      expect(
        helper,
        contains(
          'static const Duration forwardDuration = Duration(milliseconds: 240);',
        ),
      );
      expect(
        helper,
        contains(
          'static const Duration reverseDuration = Duration(milliseconds: 220);',
        ),
      );
      expect(
          helper, contains('static const Offset entryOffset = Offset(0, 1);'));
      expect(helper, contains('PageRouteBuilder<T>('));
      expect(helper, contains('SlideTransition('));
      expect(helper, contains('Curves.easeOutCubic'));
      expect(helper, contains('Curves.easeInCubic'));
    });

    test('workspace transition preserves child tree instead of replacing it',
        () {
      expect(
        helper,
        contains(
          'class HomeCardWorkspaceTransition extends StatefulWidget',
        ),
      );
      expect(helper, contains('with SingleTickerProviderStateMixin'));
      expect(
        helper,
        contains(
          'if (oldWidget.transitionKey != widget.transitionKey)',
        ),
      );
      expect(helper, contains('_controller.forward(from: 0);'));
      expect(helper, contains('child: widget.child,'));
    });

    test('desktop 40 percent left pane uses canonical workspace motion', () {
      expect(
        main,
        contains('HomeCardWorkspaceTransition('),
      );
      expect(main, contains('transitionKey: leftPaneIndex,'));
      expect(
        main,
        contains("key: ValueKey<String>('web-left-pane-\$leftPaneIndex')"),
      );
      expect(
        main,
        contains(
            'child: _staticScreens[2], // AiScreen — sempre ativo no split'),
      );
      expect(
        main,
        contains('MEDCASES_WEB_40_60_LEFT_PANE_NAV_CONTAINMENT_V1_B_R1'),
      );
    });

    test('desktop normal and mobile shells keep IndexedStack state mounted',
        () {
      expect(
        RegExp(r'HomeCardWorkspaceTransition\(').allMatches(main).length,
        greaterThanOrEqualTo(3),
      );
      expect(
        RegExp(r'IndexedStack\(').allMatches(main).length,
        greaterThanOrEqualTo(2),
      );
      expect(
        RegExp(r'index:\s*stackIdx').allMatches(main).length,
        greaterThanOrEqualTo(2),
      );
      expect(
        RegExp(r'children:\s*_staticScreens').allMatches(main).length,
        greaterThanOrEqualTo(2),
      );
      expect(main, contains('late final List<Widget> _staticScreens;'));
      expect(main, contains('_staticScreens = ['));
    });

    test('tab-backed primary Home cards retain canonical destination indices',
        () {
      expect(main, contains('void _openClinicalGuide()'));
      expect(main, contains('_onTabChange(5);'));
      expect(main, contains('void _openSimulation()'));
      expect(main, contains('_onTabChange(7);'));
      expect(main, contains('void _openVaccines()'));
      expect(main, contains('_onTabChange(6);'));
      expect(main, contains('void _onOpenNotes() => _onTabChange(10);'));

      final patient = blockForClass(home, 'HomePatientPediatricsRow');
      expect(patient, contains('onTabChange(11);'));
      expect(patient, contains('onTabChange(8);'));
      expect(patient, contains('onTabChange(4);'));
      expect(patient, contains('onTabChange(3);'));

      final utility = blockForClass(home, '_HomeAssessmentNotesTimerCardState');
      expect(utility, contains('widget.onTabChange(12);'));
      expect(utility, contains('widget.onTabChange(9);'));
    });

    test('calculator uses the same route on native and Web', () {
      final calc = blockForClass(home, 'HomeCalculatorDrugsCard');

      expect(
        calc,
        contains('Navigator.of(context, rootNavigator: !kIsWeb).push('),
      );
      expect(calc, contains('HomeCardTransition.route<void>('));
      expect(calc, contains('builder: (_) => const CalculadoraScreen(),'));
      expect(calc, isNot(contains('_HomeScreenState._slide(')));
      expect(
        calc,
        isNot(
          contains('kIsWeb && MediaQuery.of(context).size.width >= 1024'),
        ),
      );
    });

    test('Mi Guardia direct full-page actions use the universal route', () {
      final guardia = blockForClass(home, 'HomeMiGuardiaSection');

      expect(
        RegExp(r'HomeCardTransition\.route<void>\(').allMatches(guardia).length,
        2,
      );
      expect(guardia, isNot(contains('HomeScreen.slideRoute(')));
      expect(
        RegExp(r'rootNavigator:\s*!kIsWeb').allMatches(guardia).length,
        greaterThanOrEqualTo(2),
      );
      expect(
        RegExp(r'_AdultoShell\(').allMatches(guardia).length,
        greaterThanOrEqualTo(2),
      );
    });

    test('Timer remains a modal bottom sheet with aligned timing', () {
      final timer = blockForClass(home, '_HistorialCompactCardState');

      expect(timer, contains('void _openTimerSheet()'));
      expect(timer, contains('showModalBottomSheet<void>('));
      expect(
        timer,
        contains(
          'sheetAnimationStyle: HomeCardTransition.modalAnimationStyle,',
        ),
      );
      expect(timer, contains('_PomodoroSheet('));
    });

    test('rotating Web guides use the same universal route helper', () {
      expect(
        guideGrid,
        contains("import 'navigation/home_card_transition.dart';"),
      );
      expect(guideGrid, contains('HomeCardTransition.route<void>('));
      expect(guideGrid, contains('ClinicalGuideArticleScreen('));
      expect(guideGrid, isNot(contains('MaterialPageRoute<void>(')));
    });

    test('wide-Web guide showcase and native Home composition stay owned', () {
      expect(
        homeV2,
        contains('MEDCASES_WEB_HOME_40_GUIDES_2X2_ROTATING_LATEST10_V1_B_R1'),
      );
      expect(homeV2, contains('HomeWebLatestGuidesGrid('));
      expect(homeV2, contains('InlineChat('));
    });

    test('global ThemeData transition policy was not replaced', () {
      expect(main, contains('PageTransitionsTheme('));
      expect(main, contains('CupertinoPageTransitionsBuilder()'));
      expect(main, contains('FadeUpwardsPageTransitionsBuilder()'));

      expect(
        main,
        isNot(
          contains(
            'MEDCASES_HOME_GLOBAL_PAGE_TRANSITIONS_OVERRIDE',
          ),
        ),
      );
    });
  });
}

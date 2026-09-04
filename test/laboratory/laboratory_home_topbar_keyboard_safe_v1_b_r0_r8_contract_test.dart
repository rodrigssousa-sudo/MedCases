import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String lab;
  late String mainSource;

  setUpAll(() {
    lab = File('lib/screens/laboratory_screen.dart').readAsStringSync();
    mainSource = File('lib/main.dart').readAsStringSync();
  });

  group('Laboratório R8 — Home topbar + keyboard-safe search', () {
    test('tab 9 owns physical top inset like Home AI and Tools', () {
      expect(
        mainSource,
        contains(
            'isHome || _tab == 2 || _tab == 4 || _tab == 5 || _tab == 8 || _tab == 9 || _tab == 10 || _tab == 11'),
      );
      expect(
        lab,
        contains(
          'View.of(context).padding.top / View.of(context).devicePixelRatio',
        ),
      );
      expect(lab, contains('height: topPad + 48'));
      expect(lab, contains('sigmaX: 14'));
      expect(lab, contains('sigmaY: 14'));
      expect(lab, contains('left: 4'));
      expect(lab, contains('width: 36'));
      expect(lab, contains('height: 36'));
    });

    test('embedded Lab avoids nested keyboard inset', () {
      expect(
        lab,
        contains('resizeToAvoidBottomInset: !widget.embeddedInMainShell'),
      );
      expect(
        lab,
        contains('resizeToAvoidBottomInset: !embeddedInMainShell'),
      );
      expect(
        RegExp(
          r'keyboardOpen \? 16\.0 \+ safeBottom : 114\.0 \+ safeBottom',
        ).allMatches(lab).length,
        2,
      );
    });

    test('workspace releases focus predictably', () {
      expect(lab, contains('ScrollViewKeyboardDismissBehavior.onDrag'));
      expect(
        lab,
        contains('keyboardOpen ? 16.0 + safeBottom : 114.0 + safeBottom'),
      );
      expect(
        lab,
        contains(
          'FocusManager.instance.primaryFocus?.unfocus();',
        ),
      );
      expect(
        lab,
        contains(
          'FocusScope.of(context).unfocus();',
        ),
      );
    });

    test('global footer hides while Lab physical keyboard is open', () {
      expect(mainSource, contains('final labKeyboardOpen = _tab == 9 &&'));
      expect(
        mainSource,
        contains(
          'MediaQuery.viewInsetsOf(scaffoldBodyCtx).bottom > 0',
        ),
      );
      expect(
        mainSource,
        contains('labKeyboardOpen || patientKeyboardOpen'),
      );
      expect(
        RegExp(r'class\s+_FloatingFooter\s+extends\s+StatefulWidget')
            .allMatches(mainSource)
            .length,
        1,
      );
    });

    test('R7 visual and filtering contract stays intact', () {
      for (final token in <String>[
        "'FILTRO'",
        "'Limpar'",
        "'Limpiar'",
        'EdgeInsets.fromLTRB(4, 8, 4, bottomClearance)',
        'EdgeInsets.only(bottom: 3)',
        'const Color(0xFF252930)',
        'const Color(0xFFFFFFFF)',
        '114.0 + safeBottom',
      ]) {
        expect(lab, contains(token), reason: token);
      }
      expect(lab, isNot(contains('_FloatingFooter(')));
      expect(lab, isNot(contains('bottomNavigationBar:')));
    });

    test('clinical reference consumers remain present', () {
      for (final token in <String>[
        'LabReferenceCatalog.recordsForCategory',
        'record.referenceIntervals',
        'record.clinicalDecisionLimits',
        'record.criticalValues',
        'record.qualitativeValues',
        'record.sourceTitle',
      ]) {
        expect(lab, contains(token), reason: token);
      }
    });
  });
}

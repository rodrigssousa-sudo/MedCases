import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final start = source.indexOf('class $className');
  expect(start, greaterThanOrEqualTo(0), reason: className);

  final opening = source.indexOf('{', start);
  expect(opening, greaterThanOrEqualTo(0), reason: '$className opening');

  var depth = 0;

  for (var i = opening; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') depth--;

    if (depth == 0) {
      return source.substring(start, i + 1);
    }
  }

  fail('Unclosed $className');
}

void main() {
  final home = File('lib/screens/home_screen.dart').readAsStringSync();
  final mainSource = File('lib/main.dart').readAsStringSync();

  group('Pediatria — Laboratório topbar safe-area parity R7', () {
    test('tab 8 and Lab tab 9 both own physical Y zero', () {
      expect(
        mainSource,
        contains(
          'isHome || _tab == 2 || _tab == 4 || _tab == 8 || _tab == 9',
        ),
      );

      expect(mainSource, contains('final labKeyboardOpen = _tab == 9 &&'));
      expect(
        mainSource,
        contains('editorOpen || kbOpen || labKeyboardOpen'),
      );
    });

    test('Pediatrics paints physical safe top plus 48px as one glass surface',
        () {
      final shell = classBlock(home, '_PediatricsShell');

      expect(
        shell,
        contains(
          'MEDCASES_PEDIATRIA_LABORATORIO_TOPBAR_SAFE_AREA_PARITY_V1_B_R0_R7_TRANSACTIONAL',
        ),
      );
      expect(
        shell,
        contains('MEDCASES_PEDIATRIA_HOME_TOPBAR_V1_B_R0'),
      );
      expect(shell, isNot(contains('appBar: PreferredSize(')));
      expect(shell, isNot(contains('Size.fromHeight(48)')));
      expect(shell, isNot(contains('child: SafeArea(')));
      expect(
        shell,
        contains(
          'View.of(context).padding.top / View.of(context).devicePixelRatio',
        ),
      );
      expect(shell, contains('height: topPad + 48'));
      expect(shell, contains('BackdropFilter('));
      expect(
        shell,
        contains('ImageFilter.blur(sigmaX: 14, sigmaY: 14)'),
      );
      expect(
        shell,
        contains('const Color(0xFF252930).withOpacity(0.70)'),
      );
      expect(
        shell,
        contains('Colors.white.withOpacity(0.70)'),
      );
      expect(shell, isNot(contains('appBar: PreferredSize(')));
    });

    test('title back button and pediatric body are preserved', () {
      final shell = classBlock(home, '_PediatricsShell');

      expect(shell, contains("isEs ? 'PEDIATRÍA' : 'PEDIATRIA'"));
      expect(shell, contains('fontSize: 16'));
      expect(shell, contains('width: 36'));
      expect(shell, contains('height: 36'));
      expect(shell, contains('onTap: onBack ??'));
      expect(
        shell,
        contains('const Expanded(child: PediatricsTabContent())'),
      );
    });

    test('Pediatrics does not duplicate global footer', () {
      final shell = classBlock(home, '_PediatricsShell');

      expect(shell, isNot(contains('_FloatingFooter(')));
      expect(shell, isNot(contains('bottomNavigationBar:')));

      expect(
        RegExp(r'class\s+_FloatingFooter\s+extends\s+StatefulWidget')
            .allMatches(mainSource)
            .length,
        1,
      );
    });

    test('Lab R8 integration remains intact in MainShell', () {
      expect(
        mainSource,
        contains('LaboratoryMainShellWorkspace(onBack: _closeLaboratory)'),
      );
      expect(mainSource, contains('final labKeyboardOpen = _tab == 9 &&'));
    });
  });
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

String classBlock(String source, String name) {
  final match = RegExp(
    '^class\\s+${RegExp.escape(name)}\\b',
    multiLine: true,
  ).firstMatch(source);
  expect(match, isNotNull, reason: name);

  var open = source.indexOf('{', match!.start);
  expect(open, greaterThanOrEqualTo(0), reason: '$name opening brace');

  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final c = source[i];
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth == 0) return source.substring(match.start, i + 1);
    }
  }
  fail('Unclosed class $name');
}

void main() {
  late List<String> sources;

  setUpAll(() {
    sources = [
      read('lib/screens/nephrology_tools_screen.dart'),
      read('lib/screens/cardio_tools_screen.dart'),
      read('lib/screens/electrolytes_tools_screen.dart'),
      read('lib/screens/hepatology_tools_screen.dart'),
    ];
  });

  test('four result card owners converge to compact MedCases contract', () {
    for (final source in sources) {
      final card = classBlock(source, '_ResultCard');
      expect(
        card,
        contains(
          'MEDCASES_FERRAMENTAS_RESULTS_CANONICAL_PREMIUM_COMPACT_LAYOUT_V1_B_R0',
        ),
      );
      expect(card, contains('BorderRadius.circular(8)'));
      expect(card, contains('width: 0.7'));
      expect(card, contains('EdgeInsets.fromLTRB(12, 10, 12, 10)'));
      expect(card, contains('width: 30'));
      expect(card, contains('height: 30'));
      expect(card, contains('Icon(icon, color: iconColor, size: 15)'));
      expect(card, contains('fontSize: 11.5'));
    }
  });

  test('interpretation and formula use quiet neutral hierarchy', () {
    for (final source in sources) {
      final card = classBlock(source, '_ResultCard');
      expect(card, contains('Color(0xFFA8B2C1)'));
      expect(card, contains('Color(0xFF64748B)'));
      expect(card, contains('Color(0xFF7F8A99)'));
      expect(card, contains('Color(0xFF94A3B8)'));
      expect(card, contains('fontWeight: FontWeight.w500'));
      expect(card, contains('fontSize: 10'));
    }
  });

  test('results sections use canonical heading owner and compact gaps', () {
    for (final source in sources) {
      final section = classBlock(source, '_ResultsSection');
      final delegated = section.contains('_SectionLabel(');
      if (delegated) {
        expect(section, contains("'RESULTADOS'"));
        expect(
          section,
          isNot(contains('fontSize: MedTypography.sectionLabelSize')),
        );
      } else {
        expect(section, contains('fontSize: 10.5'));
        expect(section, contains('fontWeight: FontWeight.w800'));
        expect(section, contains('letterSpacing: 0.75'));
      }
      expect(section, contains('const SizedBox(height: 6)'));
      final ctaPos = section.indexOf('_DeeplinkButton(');
      expect(ctaPos, greaterThan(0));
      final beforeCta = section.substring(0, ctaPos);
      final gapMatches = RegExp(
        r'const SizedBox\(height:\s*12\),',
      ).allMatches(beforeCta).toList();
      expect(gapMatches, isNotEmpty);
      final lastGap = gapMatches.last;
      final between = beforeCta.substring(lastGap.end);
      expect(between, isNot(contains('_ResultCard(')));
      expect(section, contains('_ResultCard('));
      expect(section, contains('_DeeplinkButton('));
    }
  });

  test('support CTA becomes compact without changing callback contract', () {
    for (final source in sources) {
      final cta = classBlock(source, '_DeeplinkButton');
      expect(
        cta,
        contains('MEDCASES_FERRAMENTAS_RESULTS_CTA_SECONDARY_COMPACT_V1_B_R0'),
      );
      expect(cta, contains('height: 42'));
      expect(cta, contains('BorderRadius.circular(8)'));
      expect(cta, contains('onPressed: onTap'));
      expect(cta, contains("isEs ? 'Acceder al Soporte' : 'Acessar Suporte'"));
    }
  });

  test('premium keyboard and shared state V2 remain present', () {
    for (final source in sources) {
      expect(source, contains('decoration: TextDecoration.none'));
      expect(source, contains('Icons.arrow_forward_rounded'));
      expect(source, contains('Icons.check_rounded'));
      expect(source, contains('return 16.0 + safeBottom;'));
      expect(source, contains('return 114.0 + safeBottom;'));
      expect(source, contains('context.watch<ToolsStateProvider>()'));
    }
  });

  test('clinical wiring remains untouched', () {
    for (final source in sources) {
      expect(source, contains('_calculate()'));
      expect(
        source,
        contains('InternacionFirestoreService.updatePatientLaboratories('),
      );
      expect(source, contains('buildQueryStringForSpecialty('));
      expect(source, contains('showToolsPatientSelectionSheet('));
    }
  });
}

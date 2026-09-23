import 'history_release_runtime_harness.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final start = source.indexOf('class $className');
  expect(start, greaterThanOrEqualTo(0), reason: 'missing $className');
  final open = source.indexOf('{', start);
  expect(open, greaterThan(start));

  var depth = 0;
  var i = open;
  var quote = '';
  var inString = false;
  var line = false;
  var block = false;

  while (i < source.length) {
    if (line) {
      if (source[i] == '\n') line = false;
      i++;
      continue;
    }
    if (block) {
      if (i + 1 < source.length && source.substring(i, i + 2) == '*/') {
        block = false;
        i += 2;
      } else {
        i++;
      }
      continue;
    }
    if (inString) {
      if (source[i] == r'\') {
        i += 2;
        continue;
      }
      if (source[i] == quote) inString = false;
      i++;
      continue;
    }
    if (i + 1 < source.length && source.substring(i, i + 2) == '//') {
      line = true;
      i += 2;
      continue;
    }
    if (i + 1 < source.length && source.substring(i, i + 2) == '/*') {
      block = true;
      i += 2;
      continue;
    }
    if (source[i] == "'" || source[i] == '"') {
      inString = true;
      quote = source[i];
      i++;
      continue;
    }
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
    i++;
  }
  throw StateError('unclosed $className');
}

void main() {
  late String history;
  late String reference;
  late String row;
  late String flat;
  late String card;

  setUpAll(() {
    history = File('lib/screens/history_screen.dart').readAsStringSync();
    reference = File('lib/screens/avaliacao_screen.dart').readAsStringSync();
    row = classBlock(history, '_HcTabRow');
    flat = classBlock(history, '_HcFlatTabState');
    card = classBlock(history, '_HistoryCard');
  });

  group('Historia Clinica structural parity with Avaliacao nav V1-B-R0-R1', () {
    testWidgets('reference still contains canonical segmented navigation grammar', (tester) async {
      await verifyHistoryNavigation(tester);
      for (final token in <String>[
        'height: 40',
        'color: surface',
        'padding: EdgeInsets.zero',
        'alignment: Alignment.center',
        'padding: const EdgeInsets.symmetric(horizontal: 12)',
        'if (index < sections.length - 1)',
        'height: 2',
        'height: 1',
        'FontWeight.w700',
        'FontWeight.w700',
      ]) {
        expect(reference, contains(token), reason: token);
      }
    });

    testWidgets('History row retains the current continuous surface strip', (tester) async {
      await verifyHistoryNavigation(tester);
      expect(
        row,
        contains(
          'class _HcTabRow extends StatelessWidget',
        ),
      );
      expect(row, contains('const Color(0xFF252930)'));
      expect(row, contains('const Color(0xFFFFFFFF)'));
      expect(row, contains('height: 40'));
      expect(
        row,
        contains('child: Row('),
      );
    });

    testWidgets('real tabs retain current strip, separators and baseline', (tester) async {
      await verifyHistoryNavigation(tester);
      expect(flat, contains('height: 40'));
      expect(flat, contains('Center('));
      expect(
        flat,
        contains('left: 12'),
      );
      expect(row, contains('width: 0.7')); // separator now belongs to the strip
      expect(row, contains('height: 20')); // centered separator height
      expect(flat, contains('height: 2'));
      expect(
        flat,
        contains('color: isActive ? activeColor : inactiveColor'),
      );
      expect(flat, contains('fontSize: 12'));
      expect(flat, contains('height: 1'));
      expect(flat, contains('FontWeight.w700'));
      expect(flat, contains('FontWeight.w700'));
      expect(flat, contains('overflow: TextOverflow.ellipsis'));
    });

    testWidgets('+ Nueva/+ Nova occupies the same structural segment box', (tester) async {
      await verifyHistoryNavigation(tester);
      expect(row, contains("lang == 'es' ? '+ NUEVA' : '+ NOVA'"));
      expect(row, contains('height: 40'));
      expect(row, contains('Center('));
      expect(
        flat,
        contains('right: 12'),
      );
      expect(
        row,
        contains('bottom: BorderSide(color: divider, width: 0.7)'),
      );
      expect(row, contains('width: 0.7'));
    });

    testWidgets('current topbar clearance and prior HC card contract remain protected', (tester) async {
      await verifyHistoryNavigation(tester);
      expect(
        history,
        contains(
          'MEDCASES_HISTORIA_CLINICA_CANONICAL_SUBTOPBAR_NAV_V1_B_R0',
        ),
      );
      expect(history, contains('const SizedBox(height: 48)'));
      expect(
        history,
        contains(
          'MEDCASES_HISTORIA_CLINICA_CANONICAL_DENSITY_CARD_SURFACE_OVERFLOW_V1_B_R0_R1',
        ),
      );
      expect(
        card,
        contains(
          'color: isDark ? const Color(0xFF252930) : const Color(0xFFFFFFFF)',
        ),
      );
      expect(card, contains('Responsive Wrap:'));
      expect(card, isNot(contains('BoxShadow(')));
    });

    testWidgets('History labels and callbacks remain semantically unchanged', (tester) async {
      await verifyHistoryNavigation(tester);
      for (final token in <String>[
        "'MIS HCs'",
        "'MINHAS'",
        "'PÚBLICAS'",
        "'+ NUEVA'",
        "'+ NOVA'",
        'widget.tabCtrl.animateTo(widget.index)',
        'onNew();',
        'consumeClinicalHistoryCreationAllowance()',
        'if (!decision.allowed)',
      ]) {
        expect(history, contains(token), reason: token);
      }
    });
  });
}

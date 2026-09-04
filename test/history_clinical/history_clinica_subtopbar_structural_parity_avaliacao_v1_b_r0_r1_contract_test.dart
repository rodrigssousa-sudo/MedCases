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
    test('reference still contains canonical segmented navigation grammar', () {
      for (final token in <String>[
        'height: 44',
        'color: surface',
        'padding: const EdgeInsets.symmetric(horizontal: 8)',
        'alignment: Alignment.center',
        'padding: const EdgeInsets.symmetric(horizontal: 12)',
        'right: index < sections.length - 1',
        'width: active ? 2 : 0.7',
        'height: 1',
        'FontWeight.w800',
        'FontWeight.w600',
      ]) {
        expect(reference, contains(token), reason: token);
      }
    });

    test('History row owns the same surface strip and 8px outer inset', () {
      expect(
        row,
        contains(
          'MEDCASES_HISTORIA_CLINICA_SUBTOPBAR_STRUCTURAL_PARITY_AVALIACAO_V1_B_R0_R1',
        ),
      );
      expect(row, contains('const Color(0xFF2D3340)'));
      expect(row, contains('const Color(0xFFEFF2F5)'));
      expect(row, contains('height: 44'));
      expect(
        row,
        contains('padding: const EdgeInsets.symmetric(horizontal: 8)'),
      );
    });

    test('real tabs are segmented 44px items with right divider and baseline',
        () {
      expect(flat, contains('height: 44'));
      expect(flat, contains('alignment: Alignment.center'));
      expect(
        flat,
        contains('padding: const EdgeInsets.symmetric(horizontal: 12)'),
      );
      expect(flat, contains('right: BorderSide('));
      expect(flat, contains('width: 0.7'));
      expect(flat, contains('width: isActive ? 2 : 0.7'));
      expect(
        flat,
        contains('color: isActive ? const Color(0xFF10B981) : dividerColor'),
      );
      expect(flat, contains('fontSize: 11'));
      expect(flat, contains('height: 1'));
      expect(flat, contains('FontWeight.w800'));
      expect(flat, contains('FontWeight.w600'));
      expect(flat, contains('overflow: TextOverflow.visible'));
    });

    test('+ Nueva/+ Nova occupies the same structural segment box', () {
      expect(row, contains("lang == 'es' ? '+ NUEVA' : '+ NOVA'"));
      expect(row, contains('height: 44'));
      expect(row, contains('alignment: Alignment.center'));
      expect(
        row,
        contains('padding: const EdgeInsets.symmetric(horizontal: 12)'),
      );
      expect(
        row,
        contains('color: border.withOpacity(dark ? 0.55 : 0.85)'),
      );
      expect(row, contains('width: 0.7'));
    });

    test('0.2px topbar safety gap and prior HC card contract remain frozen', () {
      expect(
        history,
        contains(
          'MEDCASES_HISTORIA_CLINICA_CANONICAL_SUBTOPBAR_NAV_V1_B_R0',
        ),
      );
      expect(history, contains('const SizedBox(height: 0.2)'));
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

    test('History labels and callbacks remain semantically unchanged', () {
      for (final token in <String>[
        "'MIS HCs'",
        "'MINHAS'",
        "'PÚBLICAS'",
        "'+ NUEVA'",
        "'+ NOVA'",
        'widget.tabCtrl.animateTo(widget.index)',
        'onTap: onNew',
      ]) {
        expect(history, contains(token), reason: token);
      }
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final start = source.indexOf('class $className');
  expect(start, greaterThanOrEqualTo(0), reason: 'missing $className');
  final open = source.indexOf('{', start);
  expect(open, greaterThan(start));

  var depth = 0;
  var i = open;
  var inString = false;
  var quote = '';
  var inLineComment = false;
  var inBlockComment = false;

  while (i < source.length) {
    if (inLineComment) {
      if (source[i] == '\n') inLineComment = false;
      i++;
      continue;
    }
    if (inBlockComment) {
      if (i + 1 < source.length && source.substring(i, i + 2) == '*/') {
        inBlockComment = false;
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
      inLineComment = true;
      i += 2;
      continue;
    }
    if (i + 1 < source.length && source.substring(i, i + 2) == '/*') {
      inBlockComment = true;
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
  late String source;
  late String root;
  late String tabRow;
  late String flatTab;
  late String card;

  setUpAll(() {
    source = File('lib/screens/history_screen.dart').readAsStringSync();
    root = classBlock(source, '_HistoryScreenState');
    tabRow = classBlock(source, '_HcTabRow');
    flatTab = classBlock(source, '_HcFlatTabState');
    card = classBlock(source, '_HistoryCard');
  });

  group('Historia Clinica canonical density + responsive card V1-B-R0-R1', () {
    test('canonical topbar and canvas remain preserved', () {
      expect(source, contains('MEDCASES_H_CLINICA_HOME_TOPBAR_V1_B_R0'));
      expect(source, contains('fontSize: 16'));
      expect(root, contains('const SizedBox(height: 48)'));
      expect(
        root,
        contains(
          'final bg = p.darkMode ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3);',
        ),
      );
      expect(
        root,
        contains(
          'MEDCASES_HISTORIA_CLINICA_CANONICAL_DENSITY_CARD_SURFACE_OVERFLOW_V1_B_R0_R1',
        ),
      );
    });

    test('secondary tabs preserve canonical 40px height and 12px labels', () {
      expect(flatTab, contains('height: 40'));
      expect(
        flatTab,
        contains('left: 12'),
      );
      expect(flatTab, contains('fontSize: 12'));
      expect(tabRow.split('_HcFlatTab(').length - 1, 3);
      expect(tabRow, contains("'MIS HCs'"));
      expect(tabRow, contains("'MINHAS'"));
      expect(tabRow, contains("'PÚBLICAS'"));
      expect(tabRow, contains("'+ NUEVA'"));
      expect(tabRow, contains("'+ NOVA'"));
    });

    test('search and calendar are compact without changing callbacks', () {
      expect(root, contains('HISTORY_CLINICAL_V1_C_R8_SEARCH_OWNER'));
      expect(root, contains('EdgeInsets.fromLTRB(16, 6, 16, 0)'));
      expect(root, contains('height: 44'));
      expect(root, contains('borderRadius: BorderRadius.circular(8)'));
      expect(root, contains('onTap: _showDateFilter'));
      expect(root, contains('onChanged: (v) => _searchQuery.value = v'));
    });

    test('HC has explicit white/graphite surface instead of transparent canvas',
        () {
      expect(
        card,
        contains(
          'color: isDark ? const Color(0xFF252930) : const Color(0xFFFFFFFF)',
        ),
      );
      expect(
        card,
        contains(
          'color: isDark ? const Color(0xFF374151) : const Color(0xFFD8DEE7)',
        ),
      );
      expect(card, contains('borderRadius: BorderRadius.circular(12)'));
      expect(
        card,
        isNot(
          contains(
            'HISTORY_CLINICAL_V1_C_R8_LIST_SURFACE_BEGIN\n'
            '            BoxDecoration(\n'
            '          color: Colors.transparent',
          ),
        ),
      );
      expect(card, isNot(contains('BoxShadow(')));
    });

    test('header is responsive and cannot depend on rigid chips+date row', () {
      final start = card.indexOf(
        '// ── LINHA 1: categoria + estado + visibilidade + data',
      );
      final end = card.indexOf('// ── LINHA 2: Título principal', start);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final header = card.substring(start, end);

      expect(header, contains('Wrap('));
      expect(header, contains('spacing: 4'));
      expect(header, contains('runSpacing: 4'));
      expect(header, contains('WrapCrossAlignment.center'));
      expect(header, contains('h.formattedDate'));
      expect(header, isNot(contains('Spacer()')));
    });

    test('card typography and moderator actions follow compact local scale',
        () {
      expect(card, contains('fontSize: 12.5'));
      expect(card, contains('fontSize: 10'));
      expect(card, isNot(contains('MedTypography.internalTitleSize')));
      expect(card, isNot(contains('MedTypography.microTextSize')));

      final mod = card.indexOf('// ── Botões de moderação');
      expect(mod, greaterThanOrEqualTo(0));
      final tail = card.substring(mod);
      expect(tail, contains('Wrap('));
      expect(tail, contains('spacing: 6'));
      expect(tail, contains('runSpacing: 6'));
    });

    test('clinical history behavior and global-shell boundaries remain intact',
        () {
      for (final token in <String>[
        'MEDCASES_HC_NEW_HISTORY_WORKSPACE_V1_B_R0',
        'p.saveHistory(',
        'p.deleteHistory(',
        'p.toggleHistoryPublic(',
        'onTogglePublic',
        'onEdit',
        'onDelete',
        'onModHide',
        'onModDelete',
      ]) {
        expect(source, contains(token), reason: token);
      }

      expect(source, isNot(contains('bottomNavigationBar:')));
      expect(source, isNot(contains('_FloatingFooter(')));
    });
  });
}

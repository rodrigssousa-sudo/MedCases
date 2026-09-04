import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String extractBalancedOwner(
  String source,
  RegExp anchor, {
  String ownerLabel = 'owner',
}) {
  final match = anchor.firstMatch(source);

  if (match == null) {
    throw StateError('$ownerLabel não encontrado');
  }

  final openingBrace = source.indexOf('{', match.end);

  if (openingBrace < 0) {
    throw StateError('$ownerLabel sem chave de abertura');
  }

  var depth = 0;
  var state = 'code';
  var quote = '';
  var rawString = false;

  for (var index = openingBrace; index < source.length; index++) {
    final char = source[index];
    final next = index + 1 < source.length ? source[index + 1] : '';

    if (state == 'lineComment') {
      if (char == '\n') {
        state = 'code';
      }
      continue;
    }

    if (state == 'blockComment') {
      if (char == '*' && next == '/') {
        state = 'code';
        index++;
      }
      continue;
    }

    if (state == 'string') {
      if (rawString) {
        if (char == quote) {
          state = 'code';
          rawString = false;
        }
      } else if (char == '\\') {
        index++;
      } else if (char == quote) {
        state = 'code';
      }
      continue;
    }

    if (char == '/' && next == '/') {
      state = 'lineComment';
      index++;
      continue;
    }

    if (char == '/' && next == '*') {
      state = 'blockComment';
      index++;
      continue;
    }

    if (char == "'" || char == '"') {
      final previous = index > 0 ? source[index - 1] : '';
      final beforePrevious = index > 1 ? source[index - 2] : '';

      rawString = (previous == 'r' || previous == 'R') &&
          (index == 1 ||
              !RegExp(
                r'[A-Za-z0-9_]',
              ).hasMatch(beforePrevious));

      quote = char;
      state = 'string';
      continue;
    }

    if (char == '{') {
      depth++;
      continue;
    }

    if (char == '}') {
      depth--;

      if (depth == 0) {
        return source.substring(
          match.start,
          index + 1,
        );
      }
    }
  }

  throw StateError(
    '$ownerLabel sem fechamento balanceado',
  );
}

int countToken(
  String source,
  String token,
) {
  return RegExp(
    RegExp.escape(token),
  ).allMatches(source).length;
}

String maskNonCode(String source) {
  final output = StringBuffer();
  var state = 'code';
  var quote = '';
  var rawString = false;

  for (var index = 0; index < source.length; index++) {
    final char = source[index];
    final next = index + 1 < source.length ? source[index + 1] : '';

    if (state == 'lineComment') {
      if (char == '\n') {
        output.write('\n');
        state = 'code';
      } else {
        output.write(' ');
      }
      continue;
    }

    if (state == 'blockComment') {
      if (char == '*' && next == '/') {
        output.write('  ');
        index++;
        state = 'code';
      } else {
        output.write(char == '\n' ? '\n' : ' ');
      }
      continue;
    }

    if (state == 'string') {
      output.write(char == '\n' ? '\n' : ' ');
      if (!rawString && char == '\\') {
        if (index + 1 < source.length) {
          index++;
          output.write(source[index] == '\n' ? '\n' : ' ');
        }
      } else if (char == quote) {
        state = 'code';
        rawString = false;
      }
      continue;
    }

    if (char == '/' && next == '/') {
      output.write('  ');
      index++;
      state = 'lineComment';
      continue;
    }

    if (char == '/' && next == '*') {
      output.write('  ');
      index++;
      state = 'blockComment';
      continue;
    }

    final rawPrefix = (char == 'r' || char == 'R') &&
        (next == "'" || next == '"') &&
        (index == 0 || !RegExp(r'[A-Za-z0-9_]').hasMatch(source[index - 1]));

    if (rawPrefix) {
      output.write('  ');
      index++;
      quote = source[index];
      rawString = true;
      state = 'string';
      continue;
    }

    if (char == "'" || char == '"') {
      output.write(' ');
      quote = char;
      rawString = false;
      state = 'string';
      continue;
    }

    output.write(char);
  }

  return output.toString();
}

void main() {
  late String homeSource;
  late String toolsSource;
  late String patientsSource;
  late String notesSource;
  late String assessmentSource;

  late String toolsState;
  late String toolsTopbarBackground;
  late String toolsTopbarBuild;
  late String toolsTopbarContent;
  late String toolsTabRow;

  setUpAll(() {
    homeSource = File(
      'lib/screens/home_screen.dart',
    ).readAsStringSync();

    toolsSource = File(
      'lib/screens/tools_screen.dart',
    ).readAsStringSync();

    patientsSource = File(
      'lib/screens/internacion/internacion_screen.dart',
    ).readAsStringSync();

    notesSource = File(
      'lib/screens/notes_screen.dart',
    ).readAsStringSync();

    assessmentSource = File(
      'lib/screens/avaliacao_screen.dart',
    ).readAsStringSync();

    toolsState = extractBalancedOwner(
      toolsSource,
      RegExp(
        r'class\s+_ToolsScreenState\b',
        multiLine: true,
      ),
      ownerLabel: '_ToolsScreenState',
    );

    toolsTopbarBackground = extractBalancedOwner(
      toolsSource,
      RegExp(
        r'class\s+_ToolsTopbarBg\b',
        multiLine: true,
      ),
      ownerLabel: '_ToolsTopbarBg',
    );

    toolsTopbarBuild = extractBalancedOwner(
      toolsTopbarBackground,
      RegExp(
        r'Widget\s+build\s*\(\s*'
        r'BuildContext\s+context\s*\)',
        multiLine: true,
      ),
      ownerLabel: '_ToolsTopbarBg.build',
    );

    toolsTopbarContent = extractBalancedOwner(
      toolsSource,
      RegExp(
        r'class\s+_ToolsTopbarContent\b',
        multiLine: true,
      ),
      ownerLabel: '_ToolsTopbarContent',
    );

    toolsTabRow = extractBalancedOwner(
      toolsSource,
      RegExp(
        r'class\s+_ToolsTabRow\b',
        multiLine: true,
      ),
      ownerLabel: '_ToolsTabRow',
    );
  });

  test(
    'TOOLS V1-E-R2 RED — shell usa SafeArea único sem inset superior manual',
    () {
      final toolsStateCode = maskNonCode(
        toolsState,
      );

      expect(
        countToken(
          toolsStateCode,
          'SafeArea(',
        ),
        1,
      );

      expect(
        RegExp(
          r'(?:'
          r'MediaQuery\.(?:paddingOf|viewPaddingOf)\(context\)\.top|'
          r'MediaQuery\.of\(context\)\.'
          r'(?:padding|viewPadding)\.top|'
          r'View\.of\(context\)\.padding\.top'
          r')',
          multiLine: true,
        ).hasMatch(toolsStateCode),
        isFalse,
      );

      expect(
        RegExp(
          r'\bPositioned\s*\(\s*'
          r'top\s*:',
          multiLine: true,
          dotAll: true,
        ).hasMatch(toolsStateCode),
        isFalse,
      );
    },
  );

  test(
    'TOOLS V1-E-R2 GREEN — build do topbar usa vidro grafite sem sombra',
    () {
      expect(
        toolsTopbarBuild,
        contains('ClipRect('),
      );

      expect(
        toolsTopbarBuild,
        contains('BackdropFilter('),
      );

      expect(
        toolsTopbarBuild,
        contains('ImageFilter.blur('),
      );

      expect(
        RegExp(
          r'0xFF(?:1A1D23|252930|2D3340)',
          caseSensitive: false,
        ).hasMatch(toolsTopbarBuild),
        isTrue,
      );

      expect(
        toolsTopbarBuild,
        isNot(contains('BoxShadow(')),
      );

      expect(
        toolsTopbarBuild,
        isNot(contains('LinearGradient(')),
      );
    },
  );

  test(
    'TOOLS V1-E-R2 GREEN — título seta e callback de retorno permanecem',
    () {
      expect(
        toolsTopbarContent,
        contains("'FERRAMENTAS'"),
      );

      expect(
        toolsTopbarContent,
        contains(
          'Icons.arrow_back_ios_new_rounded',
        ),
      );

      expect(
        toolsTopbarContent,
        contains('nav.canPop()'),
      );

      expect(
        toolsTopbarContent,
        contains('nav.pop()'),
      );

      expect(
        toolsTopbarContent,
        contains(
          'MainShell.pendingTab.value = 0;',
        ),
      );
    },
  );

  test(
    'TOOLS V1-E-R2 GREEN — três referências canônicas usam SafeArea sem inset manual',
    () {
      final patientsOwner = extractBalancedOwner(
        patientsSource,
        RegExp(
          r'class\s+_InternacionScreenState\b',
          multiLine: true,
        ),
        ownerLabel: '_InternacionScreenState',
      );

      final notesOwner = extractBalancedOwner(
        notesSource,
        RegExp(
          r'class\s+_NotesScreenState\b',
          multiLine: true,
        ),
        ownerLabel: '_NotesScreenState',
      );

      final assessmentOwner = extractBalancedOwner(
        assessmentSource,
        RegExp(
          r'class\s+_AvalHeader\b',
          multiLine: true,
        ),
        ownerLabel: '_AvalHeader',
      );

      for (final owner in [
        patientsOwner,
        notesOwner,
        assessmentOwner,
      ]) {
        expect(
          owner,
          contains('SafeArea('),
        );

        expect(
          RegExp(
            r'MediaQuery\.of\(context\)\.'
            r'(?:padding|viewPadding)\.top',
          ).hasMatch(owner),
          isFalse,
        );
      }
    },
  );

  test(
    'TOOLS V1-E-R2 GREEN — conteúdo interativo mantém alvo de 36 px',
    () {
      expect(
        RegExp(
          r'SizedBox\s*\(\s*'
          r'width\s*:\s*36\s*,\s*'
          r'height\s*:\s*36',
          multiLine: true,
          dotAll: true,
        ).hasMatch(toolsTopbarContent),
        isTrue,
      );
    },
  );

  test(
    'TOOLS V1-E-R2 GREEN — seletor preserva quatro abas e ordem clínica',
    () {
      final labels = [
        'NEFROLOG',
        'CARDIO',
        'ELETR',
        'HEPATOLOG',
      ];

      var cursor = -1;

      for (final label in labels) {
        final next = toolsTabRow.indexOf(
          label,
          cursor + 1,
        );

        expect(
          next,
          greaterThan(cursor),
          reason: 'ordem clínica deve permanecer '
              'Nefrologia → Cardio → '
              'Eletrólitos → Hepatologia',
        );

        cursor = next;
      }
    },
  );

  test(
    'TOOLS V1-E-R2 GREEN — rota direta preserva Material transparente',
    () {
      expect(
        RegExp(
          r'Navigator\.of\(context\)\.push\s*\(\s*'
          r'_HomeScreenState\._slide\s*\(\s*'
          r'const\s+Material\s*\(\s*'
          r'type\s*:\s*MaterialType\.transparency\s*,\s*'
          r'child\s*:\s*ToolsScreen\s*\(\s*\)',
          multiLine: true,
          dotAll: true,
        ).hasMatch(homeSource),
        isTrue,
      );
    },
  );

  test(
    'TOOLS V1-E-R2 GREEN — montagem embutida continua sem header duplicado',
    () {
      expect(
        RegExp(
          r'class\s+_CalculadorasShell\b'
          r'[\s\S]*?ToolsScreen\s*\(\s*'
          r'hideHeader\s*:\s*true\s*\)',
          multiLine: true,
          dotAll: true,
        ).hasMatch(homeSource),
        isTrue,
      );
    },
  );
}

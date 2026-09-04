import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String readSource(String path) {
  return File(path).readAsStringSync();
}

String maskNonCode(String source) {
  final output = StringBuffer();
  var state = 'code';
  var quote = '';
  var rawString = false;
  var tripleString = false;

  for (var index = 0; index < source.length; index++) {
    final char = source[index];
    final next = index + 1 < source.length ? source[index + 1] : '';
    final nextTwo = index + 2 < source.length ? source[index + 2] : '';

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
      if (tripleString) {
        if (char == quote && next == quote && nextTwo == quote) {
          output.write('   ');
          index += 2;
          state = 'code';
          rawString = false;
          tripleString = false;
        } else {
          output.write(char == '\n' ? '\n' : ' ');
        }
        continue;
      }

      output.write(char == '\n' ? '\n' : ' ');

      if (!rawString && char == '\\') {
        if (index + 1 < source.length) {
          index++;
          output.write(
            source[index] == '\n' ? '\n' : ' ',
          );
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
        (index == 0 ||
            !RegExp(
              r'[A-Za-z0-9_]',
            ).hasMatch(source[index - 1]));

    if (rawPrefix) {
      final rawQuote = next;
      final isTriple = index + 3 < source.length &&
          source[index + 2] == rawQuote &&
          source[index + 3] == rawQuote;

      output.write(isTriple ? '    ' : '  ');
      index += isTriple ? 3 : 1;
      quote = rawQuote;
      rawString = true;
      tripleString = isTriple;
      state = 'string';
      continue;
    }

    if (char == "'" || char == '"') {
      final isTriple = next == char && nextTwo == char;

      output.write(isTriple ? '   ' : ' ');
      index += isTriple ? 2 : 0;
      quote = char;
      rawString = false;
      tripleString = isTriple;
      state = 'string';
      continue;
    }

    output.write(char);
  }

  return output.toString();
}

String classBlock(
  String source,
  String className,
) {
  final masked = maskNonCode(source);
  final match = RegExp(
    '^class\\s+${RegExp.escape(className)}\\b',
    multiLine: true,
  ).firstMatch(masked);

  if (match == null) {
    throw StateError('Classe ausente: $className');
  }

  final opening = masked.indexOf('{', match.end);
  var depth = 0;

  for (var index = opening; index < masked.length; index++) {
    final char = masked[index];

    if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;

      if (depth == 0) {
        return source.substring(
          match.start,
          index + 1,
        );
      }
    }
  }

  throw StateError('Classe sem fechamento: $className');
}

void expectInputCardWrapperIsFlat(
  String source, {
  required bool expectsTitle,
}) {
  final owner = classBlock(
    source,
    '_InputCard',
  );
  final code = maskNonCode(owner);

  if (expectsTitle) {
    expect(
      owner,
      contains('final String title;'),
    );
  } else {
    expect(
      owner,
      isNot(contains('final String title;')),
    );
  }

  expect(
    owner,
    contains('final Widget child;'),
  );
  expect(
    code,
    isNot(contains('BoxDecoration(')),
  );
  expect(
    code,
    isNot(contains('Border.all(')),
  );
  expect(
    code,
    isNot(contains('BorderRadius.circular(')),
  );
}

void main() {
  late String tools;
  late String home;
  late String nephrology;
  late String cardio;
  late String electrolytes;
  late String hepatology;

  setUpAll(() {
    tools = readSource(
      'lib/screens/tools_screen.dart',
    );
    home = readSource(
      'lib/screens/home_screen.dart',
    );
    nephrology = readSource(
      'lib/screens/nephrology_tools_screen.dart',
    );
    cardio = readSource(
      'lib/screens/cardio_tools_screen.dart',
    );
    electrolytes = readSource(
      'lib/screens/electrolytes_tools_screen.dart',
    );
    hepatology = readSource(
      'lib/screens/hepatology_tools_screen.dart',
    );
  });

  test(
    'TOOLS V1-F-R2 GREEN — geometria título seta e retorno do topbar permanecem',
    () {
      expect(tools, contains('height: 56'));
      expect(tools, contains('FERRAMENTAS'));
      expect(
        tools,
        contains('Icons.arrow_back_ios_new_rounded'),
      );
      expect(tools, contains('nav.canPop()'));
      expect(
        tools,
        contains('MainShell.pendingTab.value = 0'),
      );
    },
  );

  test(
    'TOOLS V1-F-R2 GREEN — quatro especialidades e ordem clínica permanecem',
    () {
      final nephroIndex = tools.indexOf(
        'const NephrologyToolsScreen()',
      );
      final cardioIndex = tools.indexOf(
        'const CardioToolsScreen()',
      );
      final electroIndex = tools.indexOf(
        'const ElectrolytesToolsScreen()',
      );
      final hepatoIndex = tools.indexOf(
        'const HepatologyToolsScreen()',
      );

      expect(nephroIndex, greaterThanOrEqualTo(0));
      expect(cardioIndex, greaterThan(nephroIndex));
      expect(electroIndex, greaterThan(cardioIndex));
      expect(hepatoIndex, greaterThan(electroIndex));
    },
  );

  test(
    'TOOLS V1-F-R2 GREEN — campos e owners clínicos funcionais permanecem',
    () {
      final contracts = <String, String>{
        nephrology: 'NephrologyToolsScreen',
        cardio: 'CardioToolsScreen',
        electrolytes: 'ElectrolytesToolsScreen',
        hepatology: 'HepatologyToolsScreen',
      };

      for (final entry in contracts.entries) {
        expect(entry.key, contains(entry.value));
        expect(
          RegExp(
            r'\bText(?:Form)?Field\s*\(',
          ).hasMatch(
            maskNonCode(entry.key),
          ),
          isTrue,
        );
      }
    },
  );

  test(
    'TOOLS V1-F-R2 GREEN — Material ancestor e montagem hideHeader permanecem',
    () {
      expect(
        home,
        contains('MaterialType.transparency'),
      );
      expect(
        RegExp(
          r'ToolsScreen\s*\(\s*'
          r'hideHeader\s*:\s*true\s*'
          r'\)',
          multiLine: true,
        ).hasMatch(home),
        isTrue,
      );
      expect(
        RegExp(
          r'child\s*:\s*(?:const\s+)?'
          r'ToolsScreen\s*\(\s*\)',
          multiLine: true,
        ).hasMatch(home),
        isTrue,
      );
    },
  );

  test(
    'TOOLS V1-F-R2 RED — topbar usa vidro grafite sem alterar geometria',
    () {
      final state = classBlock(
        tools,
        '_ToolsScreenState',
      );
      final background = classBlock(
        tools,
        '_ToolsTopbarBg',
      );
      final combined = '$state\n$background';

      expect(combined, contains('BackdropFilter('));
      expect(combined, contains('ImageFilter.blur('));
      expect(
        RegExp(
          r'0xFF(?:1A1D23|252930|2D3340)',
        ).hasMatch(combined),
        isTrue,
      );
      expect(
        RegExp(
          r'(?:withOpacity|withValues)\s*\(',
        ).hasMatch(combined),
        isTrue,
      );
      expect(combined, isNot(contains('BoxShadow(')));
    },
  );

  test(
    'TOOLS V1-F-R2 RED — seletor principal usa verde MedCases e não ciano',
    () {
      final tabRow = classBlock(
        tools,
        '_ToolsTabRow',
      );
      final flatTab = classBlock(
        tools,
        '_ToolsFlatTabState',
      );
      final combined = '$tabRow\n$flatTab';

      expect(
        RegExp(
          r'0xFF(?:00C781|008F66|10B981|059669)',
          caseSensitive: false,
        ).hasMatch(combined),
        isTrue,
      );
      expect(
        RegExp(
          r'0xFF(?:00E5FF|00B4CC|06B6D4|0891B2)',
          caseSensitive: false,
        ).hasMatch(combined),
        isFalse,
      );
    },
  );

  test(
    'TOOLS V1-F-R2 RED — Nefrologia remove wrapper visual externo de _InputCard',
    () {
      expectInputCardWrapperIsFlat(
        nephrology,
        expectsTitle: false,
      );
    },
  );

  test(
    'TOOLS V1-F-R2 RED — Cardio remove wrapper visual externo de _InputCard',
    () {
      expectInputCardWrapperIsFlat(
        cardio,
        expectsTitle: true,
      );
    },
  );

  test(
    'TOOLS V1-F-R2 RED — Eletrólitos remove wrapper visual externo de _InputCard',
    () {
      expectInputCardWrapperIsFlat(
        electrolytes,
        expectsTitle: true,
      );
    },
  );

  test(
    'TOOLS V1-F-R2 RED — Hepatologia remove wrapper visual externo de _InputCard',
    () {
      expectInputCardWrapperIsFlat(
        hepatology,
        expectsTitle: false,
      );
    },
  );

  test(
    'TOOLS V1-F-R2 RED — ação clínica da Hepatologia abandona ciano e adota verde',
    () {
      final action = classBlock(
        hepatology,
        '_DeeplinkButton',
      );

      expect(
        RegExp(
          r'0xFF(?:00C781|008F66|10B981|059669)',
          caseSensitive: false,
        ).hasMatch(action),
        isTrue,
      );
      expect(
        RegExp(
          r'0xFF(?:00E5FF|00B4CC|06B6D4|0891B2)',
          caseSensitive: false,
        ).hasMatch(action),
        isFalse,
      );
      expect(action, isNot(contains('LinearGradient(')));
    },
  );
}

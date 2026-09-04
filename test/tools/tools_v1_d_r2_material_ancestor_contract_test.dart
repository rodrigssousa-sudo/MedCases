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
          (index == 1 || !RegExp(r'[A-Za-z0-9_]').hasMatch(beforePrevious));
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
        return source.substring(match.start, index + 1);
      }
    }
  }

  throw StateError('$ownerLabel sem fechamento balanceado');
}

void main() {
  late String homeSource;
  late String toolsSource;
  late String mainSource;
  late String nephrologySource;
  late String cardioSource;
  late String electrolytesSource;
  late String hepatologySource;

  setUpAll(() {
    homeSource = File('lib/screens/home_screen.dart').readAsStringSync();
    toolsSource = File('lib/screens/tools_screen.dart').readAsStringSync();
    mainSource = File('lib/main.dart').readAsStringSync();
    nephrologySource =
        File('lib/screens/nephrology_tools_screen.dart').readAsStringSync();
    cardioSource =
        File('lib/screens/cardio_tools_screen.dart').readAsStringSync();
    electrolytesSource =
        File('lib/screens/electrolytes_tools_screen.dart').readAsStringSync();
    hepatologySource =
        File('lib/screens/hepatology_tools_screen.dart').readAsStringSync();
  });

  test(
    'TOOLS V1-D-R2 RED — rota direta fornece Material ancestor transparente',
    () {
      final directMaterialRoute = RegExp(
        r'Navigator\.of\(context\)\.push\s*\(\s*'
        r'_HomeScreenState\._slide\s*\(\s*'
        r'const\s+Material\s*\(\s*'
        r'type\s*:\s*MaterialType\.transparency\s*,\s*'
        r'child\s*:\s*ToolsScreen\s*\(\s*\)\s*,?\s*'
        r'\)\s*,?\s*\)\s*,?\s*\)',
        multiLine: true,
        dotAll: true,
      );

      expect(
        directMaterialRoute.allMatches(homeSource).length,
        1,
        reason: 'A rota direta de Ferramentas deve fornecer um Material '
            'transparente sem alterar o ToolsScreen interno.',
      );
    },
  );

  test(
    'TOOLS V1-D-R2 GREEN — topbar direto permanece visível',
    () {
      expect(
        RegExp(
          r'const\s+ToolsScreen\s*\(\s*'
          r'hideHeader\s*:\s*true',
          multiLine: true,
        ).hasMatch(homeSource),
        isFalse,
      );
      expect(
        homeSource,
        contains('Navigator.of(context).push('),
      );
    },
  );

  test(
    'TOOLS V1-D-R2 GREEN — _slide genérico permanece sem wrapper global',
    () {
      final owner = extractBalancedOwner(
        homeSource,
        RegExp(
          r'static\s+Route\s+_slide\s*\(\s*Widget\s+page\s*\)',
          multiLine: true,
        ),
        ownerLabel: '_HomeScreenState._slide',
      );

      expect(owner, contains('PageRouteBuilder('));
      expect(owner, contains('pageBuilder: (_, __, ___) => page'));
      expect(owner, contains('SlideTransition('));
      expect(
        owner,
        contains(
          'transitionDuration: const Duration(milliseconds: 280)',
        ),
      );
      expect(owner, isNot(contains('Material(')));
      expect(owner, isNot(contains('Scaffold(')));
    },
  );

  test(
    'TOOLS V1-D-R2 GREEN — montagem embutida permanece sem header duplicado',
    () {
      final embeddedOwner = RegExp(
        r'class\s+_CalculadorasShell\b'
        r'(?:(?!\nclass\s).)*?'
        r'ToolsScreen\s*\(\s*hideHeader\s*:\s*true\s*\)',
        multiLine: true,
        dotAll: true,
      );

      expect(embeddedOwner.allMatches(homeSource).length, 1);
      expect(
        RegExp(r'\bToolsScreen\s*\(\s*\)').allMatches(mainSource).length,
        1,
      );
    },
  );

  test(
    'TOOLS V1-D-R2 GREEN — ToolsScreen interno permanece sem Material ou Scaffold',
    () {
      final widgetOwner = extractBalancedOwner(
        toolsSource,
        RegExp(r'class\s+ToolsScreen\b', multiLine: true),
        ownerLabel: 'ToolsScreen',
      );
      final stateOwner = extractBalancedOwner(
        toolsSource,
        RegExp(
          r'class\s+_ToolsScreenState\b',
          multiLine: true,
        ),
        ownerLabel: '_ToolsScreenState',
      );
      final internalOwners = '$widgetOwner\n$stateOwner';

      expect(
        stateOwner,
        contains('final showHeader = !widget.hideHeader;'),
      );
      expect(
        RegExp(r'\bMaterial\s*\(').allMatches(internalOwners).length,
        0,
      );
      expect(
        RegExp(r'\bScaffold\s*\(').allMatches(internalOwners).length,
        0,
      );
    },
  );

  test(
    'TOOLS V1-D-R2 GREEN — título seta e retorno do topbar permanecem',
    () {
      expect(toolsSource, contains("'FERRAMENTAS'"));
      expect(
        toolsSource,
        contains('Icons.arrow_back_ios_new_rounded'),
      );
      expect(
        toolsSource,
        contains('final nav = Navigator.of(context);'),
      );
      expect(toolsSource, contains('nav.canPop()'));
      expect(toolsSource, contains('nav.pop()'));
      expect(
        toolsSource,
        contains('MainShell.pendingTab.value = 0;'),
      );
    },
  );

  test(
    'TOOLS V1-D-R2 GREEN — Cardio e Eletrólitos preservam roots e inputs',
    () {
      expect(cardioSource, contains('class CardioToolsScreen'));
      expect(
        cardioSource,
        contains('TextFormField('),
      );
      expect(
        RegExp(r'\bMaterial\s*\(').hasMatch(cardioSource),
        isFalse,
      );
      expect(
        RegExp(r'\bScaffold\s*\(').hasMatch(cardioSource),
        isFalse,
      );

      expect(
        electrolytesSource,
        contains('class ElectrolytesToolsScreen'),
      );
      expect(
        electrolytesSource,
        contains('TextFormField('),
      );
      expect(
        RegExp(r'\bMaterial\s*\(').hasMatch(electrolytesSource),
        isFalse,
      );
      expect(
        RegExp(r'\bScaffold\s*\(').hasMatch(electrolytesSource),
        isFalse,
      );
    },
  );

  test(
    'TOOLS V1-D-R2 GREEN — Nefrologia e Hepatologia preservam Scaffold local',
    () {
      expect(
        nephrologySource,
        contains('class NephrologyToolsScreen'),
      );
      expect(nephrologySource, contains('Scaffold('));
      expect(
        nephrologySource,
        contains('TextFormField('),
      );

      expect(
        hepatologySource,
        contains('class HepatologyToolsScreen'),
      );
      expect(hepatologySource, contains('Scaffold('));
      expect(
        hepatologySource,
        contains('TextFormField('),
      );
    },
  );
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String homeSource;
  late String toolsSource;
  late String mainSource;

  setUpAll(() {
    homeSource = File('lib/screens/home_screen.dart').readAsStringSync();
    toolsSource = File('lib/screens/tools_screen.dart').readAsStringSync();
    mainSource = File('lib/main.dart').readAsStringSync();
  });

  test(
    'TOOLS V1-B RED — rota direta da Home V2 exibe o topbar de Ferramentas',
    () {
      final hiddenDirectRoute = RegExp(
        r'const\s+ToolsScreen\s*\(\s*hideHeader\s*:\s*true\s*,?\s*\)',
        multiLine: true,
      ).allMatches(homeSource);

      expect(
        hiddenDirectRoute.length,
        0,
        reason: 'A rota direta via Navigator.push não pode ocultar o topbar.',
      );
    },
  );

  test('TOOLS V1-B GREEN — rota direta permanece única', () {
    final directRoute = RegExp(
      r'Navigator\.of\(context\)\.push\s*\(\s*'
      r'_HomeScreenState\._slide\s*\(\s*'
      r'(?:const\s+ToolsScreen\s*\(\s*\)|'
      r'const\s+Material\s*\(\s*'
      r'type\s*:\s*MaterialType\.transparency\s*,\s*'
      r'child\s*:\s*ToolsScreen\s*\(\s*\)\s*,?\s*'
      r'\))'
      r'\s*,?\s*\)\s*,?\s*\)',
      multiLine: true,
      dotAll: true,
    );

    expect(directRoute.allMatches(homeSource).length, 1);
    expect(homeSource, contains('toolsScreenTabNotifier.value = 0;'));
  });

  test(
    'TOOLS V1-B GREEN — montagem embutida continua sem header duplicado',
    () {
      final embeddedOwner = RegExp(
        r'class\s+_CalculadorasShell\b'
        r'(?:(?!\nclass\s).)*?'
        r'ToolsScreen\s*\(\s*hideHeader\s*:\s*true\s*\)',
        multiLine: true,
        dotAll: true,
      );

      expect(
        embeddedOwner.allMatches(homeSource).length,
        1,
        reason: '_CalculadorasShell deve continuar montando Ferramentas sem '
            'um segundo topbar.',
      );
    },
  );

  test(
    'TOOLS V1-B GREEN — MainShell preserva o header pelo valor padrão',
    () {
      final shellCalls = RegExp(
        r'\bToolsScreen\s*\(\s*\)',
      ).allMatches(mainSource);

      expect(shellCalls.length, 1);
      expect(toolsSource, contains('this.hideHeader = false'));
      expect(
        toolsSource,
        contains('final showHeader = !widget.hideHeader;'),
      );
    },
  );

  test(
    'TOOLS V1-B GREEN — topbar preserva título, seta e retorno produtivo',
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

  test('TOOLS V1-B GREEN — seletores 0, 1, 2 e 3 são preservados', () {
    for (final index in <int>[0, 1, 2, 3]) {
      expect(
        RegExp(r'index\s*:\s*' + index.toString())
            .allMatches(toolsSource)
            .length,
        greaterThanOrEqualTo(1),
      );
    }

    expect(toolsSource, contains("'NEFROLOGÍA'"));
    expect(toolsSource, contains("'NEFROLOGIA'"));
    expect(toolsSource, contains("'CARDIO'"));
    expect(toolsSource, contains("'ELECTROLITOS'"));
    expect(toolsSource, contains("'ELETRÓLITOS'"));
    expect(toolsSource, contains("'HEPATOLOGÍA'"));
  });

  test(
    'TOOLS V1-B GREEN — ordem clínica é idêntica nas duas TabBarView',
    () {
      final orderedTabs = RegExp(
        r'TabBarView\s*\([\s\S]*?'
        r'NephrologyToolsScreen\s*\([\s\S]*?'
        r'CardioToolsScreen\s*\([\s\S]*?'
        r'ElectrolytesToolsScreen\s*\([\s\S]*?'
        r'HepatologyToolsScreen\s*\(',
        multiLine: true,
      ).allMatches(toolsSource);

      expect(orderedTabs.length, 2);
    },
  );

  test(
    'TOOLS V1-B GREEN — notifier e lifecycle do shell permanecem intactos',
    () {
      expect(
        toolsSource,
        contains('TabController(length: 4'),
      );
      expect(
        toolsSource,
        contains('toolsScreenTabNotifier.addListener'),
      );
      expect(
        toolsSource,
        contains('toolsScreenTabNotifier.removeListener'),
      );
      expect(
        toolsSource,
        contains('toolsScreenVisibleNotifier.addListener'),
      );
      expect(
        toolsSource,
        contains('toolsScreenVisibleNotifier.removeListener'),
      );
      expect(toolsSource, contains('_tabCtrl.dispose()'));
    },
  );
}

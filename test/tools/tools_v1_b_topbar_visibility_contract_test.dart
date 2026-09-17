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
    // O ponto de entrada público atual troca para o único ToolsScreen da
    // MainShell, em vez de empilhar outra instância no Navigator.
    final entry = RegExp(
      r'onTools:\s*\(\)\s*\{\s*'
      r'AppHaptics\.light\(context\);\s*'
      r'toolsScreenTabNotifier\.value\s*=\s*null;\s*'
      r'onTabChange\(4\);',
      multiLine: true,
    );
    expect(entry.allMatches(homeSource).length, greaterThanOrEqualTo(1));
    expect(mainSource, contains('const RepaintBoundary(child: ToolsScreen())'));
    expect(homeSource, isNot(contains('ToolsScreen(hideHeader: false)')));
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
      // O título migrou de FERRAMENTAS para +SCORES; a navegação permanece
      // no owner _ToolsTopbarContent, não na antiga TabRow.
      expect(toolsSource, contains('class _ToolsTopbarContent extends StatelessWidget'));
      expect(toolsSource, contains("'+SCORES'"));
      expect(toolsSource, contains('Icons.arrow_back_ios_new_rounded'));
      expect(toolsSource, contains('final nav = Navigator.of(context);'));
      expect(toolsSource, contains('nav.canPop()'));
      expect(toolsSource, contains('nav.pop()'));
      expect(toolsSource, contains('MainShell.pendingTab.value = 0;'));
      expect(toolsSource, contains('height: 48'));
    },
  );

  test('TOOLS V1-B GREEN — seletores 0, 1, 2 e 3 são preservados', () {
    // Os quatro deeplinks usam workspaces dedicados e permanecem alcançáveis
    // a partir do catálogo de especialidades (+SCORES).
    final start = toolsSource.indexOf('void _openToolsSpecialtyRoute(');
    final end = toolsSource.indexOf('class _ToolsHubLanding', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final route = toolsSource.substring(start, end);
    final branches = RegExp(r'if \(index == ([0-3])\) \{').allMatches(route).toList();
    expect(branches.length, 4);
    final destinations = <String>[
      'NephroPremiumWorkspaceScreen',
      'CardioPremiumWorkspaceScreen',
      'ElectrolytesPremiumWorkspaceScreen',
      'HepatoPremiumWorkspaceScreen',
    ];
    for (var index = 0; index < 4; index++) {
      expect(branches[index].group(1), '$index');
      final stop = index + 1 < branches.length
          ? branches[index + 1].start
          : route.length;
      final block = route.substring(branches[index].start, stop);
      expect(block, contains('const ${destinations[index]}()'));
      expect(
        toolsSource,
        contains('onTap: () => _openToolsSpecialtyRoute(context, $index)'),
      );
    }
  });

  test(
    'TOOLS V1-B GREEN — ordem clínica é idêntica nas duas TabBarView',
    () {
      // As duas TabBarView foram substituídas por um catálogo único.
      final start = toolsSource.indexOf('class _ToolsHubLanding extends StatelessWidget');
      final end = toolsSource.indexOf('class _PlusScoresUnifiedSpecialtyItem', start);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final hub = toolsSource.substring(start, end);
      expect(hub, contains('final items = <_PlusScoresUnifiedSpecialtyItem>['));
      expect(RegExp(r'_PlusScoresUnifiedSpecialtyItem\(').allMatches(hub).length, 22);
      for (final title in <String>[
        "titleEs: 'Cardiología'",
        "titleEs: 'Electrolitos'",
        "titleEs: 'Nefrología'",
        "titleEs: 'Hepatología'",
      ]) {
        expect(hub, contains(title));
      }
      expect(toolsSource, contains('child: const _ToolsHubLanding()'));
      expect(toolsSource, isNot(contains('TabBarView(')));
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

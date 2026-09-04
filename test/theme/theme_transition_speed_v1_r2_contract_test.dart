import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

String classSlice(String text, String start, String end) {
  final startIndex = text.indexOf(start);
  final endIndex = text.indexOf(end, startIndex + start.length);

  expect(startIndex, greaterThanOrEqualTo(0), reason: start);
  expect(endIndex, greaterThan(startIndex), reason: end);

  return text.substring(startIndex, endIndex);
}

void main() {
  group('Theme transition speed V1-R2', () {
    late String main;
    late String appProvider;
    late String drawerBlock;
    late String themeToggle;

    setUpAll(() {
      main = source('lib/main.dart');
      appProvider = source('lib/providers/app_provider.dart');

      drawerBlock = classSlice(
        main,
        'class _DrawerBlock extends StatelessWidget {',
        'class _DrawerItemPremium extends StatelessWidget {',
      );

      themeToggle = classSlice(
        main,
        'class _ThemeToggle extends StatelessWidget {',
        'class _OnOffToggle extends StatelessWidget {',
      );
    });

    test('troca global não possui animação intermediária', () {
      expect(
        main,
        contains('themeAnimationDuration: Duration.zero'),
      );
      expect(
        main,
        contains('themeAnimationCurve: Curves.linear'),
      );
      expect(
        main,
        isNot(
          contains(
            'themeAnimationDuration: const Duration(milliseconds: 140)',
          ),
        ),
      );
    });

    test('DrawerBlock usa a mesma fonte imediata do botão', () {
      expect(
        drawerBlock,
        contains(
          'context.select<AppProvider, bool>((p) => p.darkMode)',
        ),
      );
      expect(
        drawerBlock,
        isNot(
          contains(
            'Theme.of(context).brightness == Brightness.dark',
          ),
        ),
      );
    });

    test('switch visual conclui em até noventa milissegundos', () {
      expect(
        themeToggle,
        contains('Duration(milliseconds: 90)'),
      );
      expect(
        themeToggle,
        isNot(contains('Duration(milliseconds: 200)')),
      );
    });

    test('preserva raiz stateful, Navigator e AuthGate estáveis', () {
      for (final token in const <String>[
        'class MedCasesApp extends StatefulWidget',
        'class _MedCasesAppState extends State<MedCasesApp>',
        'navigatorKey: _rootNavigatorKey',
        'home: _stableAuthGate',
      ]) {
        expect(main, contains(token), reason: token);
      }
    });

    test('não fecha Drawer, não muda aba e não cria navegação paralela', () {
      final appearanceStart = main.indexOf(
        "title: p.lang == 'es' ? 'Apariencia' : 'Aparência'",
      );
      expect(appearanceStart, greaterThanOrEqualTo(0));

      final appearanceSlice = main.substring(
        appearanceStart,
        main.indexOf(
          '// Vibração tátil removida',
          appearanceStart,
        ),
      );

      expect(
        appearanceSlice,
        contains('onTap: () => p.toggleDarkMode()'),
      );
      expect(appearanceSlice, isNot(contains('Navigator.')));
      expect(appearanceSlice, isNot(contains('pendingTab')));
    });

    test('persistência canônica do tema permanece intacta', () {
      for (final token in const <String>[
        'void toggleDarkMode()',
        '_darkMode = !_darkMode',
        '_saveLocal()',
        'FirestoreService.updateUserProfile(',
        'uiProvider.syncValues(',
        'notifyListeners()',
      ]) {
        expect(appProvider, contains(token), reason: token);
      }
    });
  });
}

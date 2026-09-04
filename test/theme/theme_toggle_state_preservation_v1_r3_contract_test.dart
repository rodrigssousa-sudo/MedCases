import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  group('Theme state preservation V1-R3', () {
    late String main;
    late String appProvider;
    late String uiProvider;

    setUpAll(() {
      main = source('lib/main.dart');
      appProvider = source('lib/providers/app_provider.dart');
      uiProvider = source('lib/providers/ui_provider.dart');
    });

    test('MedCasesApp mantém identidade stateful durante o tema', () {
      expect(main, contains('class MedCasesApp extends StatefulWidget'));
      expect(
          main, contains('class _MedCasesAppState extends State<MedCasesApp>'));
      expect(
        main,
        isNot(contains('class MedCasesApp extends StatelessWidget')),
      );
    });

    test('Navigator raiz e AuthGate possuem identidades estáveis', () {
      for (final token in const <String>[
        'final GlobalKey<NavigatorState> _rootNavigatorKey',
        'late final _AuthGate _stableAuthGate',
        '_stableAuthGate = _AuthGate(firebaseInit: widget.firebaseInit)',
        'navigatorKey: _rootNavigatorKey',
        'home: _stableAuthGate',
      ]) {
        expect(main, contains(token), reason: token);
      }

      expect(
        main,
        isNot(contains('home: _AuthGate(firebaseInit: firebaseInit)')),
      );
    });

    test('troca visual não substitui MainShell nem IndexedStack', () {
      for (final token in const <String>[
        'class MainShell extends StatefulWidget',
        'int _tab =',
        'late final List<Widget> _staticScreens',
      ]) {
        expect(main, contains(token), reason: token);
      }

      expect(
        RegExp(
          r'IndexedStack\(\s*index:\s*stackIdx\s*,\s*children:\s*_staticScreens\s*,?\s*\)',
        ).hasMatch(main),
        isTrue,
        reason:
            'IndexedStack keeps stackIdx + _staticScreens independent of formatter wrapping',
      );

      expect(main, isNot(contains('UniqueKey()')));
      expect(main, isNot(contains('pushAndRemoveUntil')));
    });

    test('camada transitória troca sem estado híbrido', () {
      expect(
        main,
        contains('themeAnimationDuration: Duration.zero'),
      );
      expect(main, contains('themeAnimationCurve: Curves.linear'));
      expect(
        RegExp(
          r'color:\s*darkMode\s*\?\s*const Color\(0xFF0F1116\)'
          r'\s*:\s*const Color\(0xFFFFFFFF\)',
        ).allMatches(main).length,
        greaterThanOrEqualTo(2),
      );
    });

    test('persistência canônica do tema permanece no AppProvider', () {
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

      expect(uiProvider, contains('if (changed) notifyListeners()'));
    });

    test('não cria infraestrutura paralela de tema ou navegação', () {
      for (final forbidden in const <String>[
        'runApp(MedCasesApp',
        'Navigator.of(context).pushReplacement',
        'Navigator.of(context).pushAndRemoveUntil',
        'selectedIndex = 0;',
        'currentIndex = 0;',
      ]) {
        expect(
          main.substring(main.indexOf('class MedCasesApp')),
          isNot(contains(forbidden)),
          reason: forbidden,
        );
      }
    });
  });
}

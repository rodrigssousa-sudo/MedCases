import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String homeV2Source;
  late String legacyHomeSource;

  setUpAll(() {
    homeV2Source = File('lib/home_v2/home_screen_v2.dart').readAsStringSync();
    legacyHomeSource = File('lib/screens/home_screen.dart').readAsStringSync();
  });

  group('Injeção do chat real na Home V2', () {
    test('HomeScreen mantém slot opcional para o chat', () {
      expect(
        legacyHomeSource,
        contains('final Widget? inlineChat;'),
      );
      expect(
        legacyHomeSource,
        contains('this.inlineChat,'),
      );
      expect(
        legacyHomeSource,
        contains('widget.inlineChat ??'),
      );
    });

    test('HomeScreenV2 monta diretamente o adaptador oficial', () {
      expect(
        RegExp(r'\bInlineChat\s*\(').allMatches(homeV2Source).length,
        1,
      );
      expect(
        homeV2Source,
        contains('onNavigateToAi: onTabChange'),
      );
      expect(
        homeV2Source,
        isNot(contains('inlineChat:')),
      );
    });

    test('HomeScreenV2 não delega mais sua estrutura à Home antiga', () {
      expect(
        homeV2Source,
        isNot(contains('return HomeScreen(')),
      );
      expect(
        homeV2Source,
        contains('SingleChildScrollView('),
      );
    });
  });
}

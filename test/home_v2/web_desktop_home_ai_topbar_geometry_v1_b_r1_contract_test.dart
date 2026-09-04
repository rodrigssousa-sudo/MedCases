import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/screens/ai/widgets/wa_header.dart';

String classBlock(String source, String declaration) {
  final start = source.indexOf(declaration);
  expect(start, greaterThanOrEqualTo(0), reason: 'Classe ausente: $declaration');

  final opening = source.indexOf('{', start);
  var depth = 0;
  String? quote;
  var escaped = false;
  var lineComment = false;
  var blockComment = false;

  for (var index = opening; index < source.length; index++) {
    final character = source[index];
    final pair = index + 1 < source.length
        ? source.substring(index, index + 2)
        : character;

    if (lineComment) {
      if (character == '\n') lineComment = false;
      continue;
    }

    if (blockComment) {
      if (pair == '*/') {
        blockComment = false;
        index++;
      }
      continue;
    }

    if (quote != null) {
      if (escaped) {
        escaped = false;
        continue;
      }
      if (character == '\\') {
        escaped = true;
        continue;
      }
      if (character == quote) quote = null;
      continue;
    }

    if (pair == '//') {
      lineComment = true;
      index++;
      continue;
    }

    if (pair == '/*') {
      blockComment = true;
      index++;
      continue;
    }

    if (character == "'" || character == '"') {
      quote = character;
      continue;
    }

    if (character == '{') {
      depth++;
    } else if (character == '}') {
      depth--;
      if (depth == 0) return source.substring(start, index + 1);
    }
  }

  fail('Classe sem fechamento: $declaration');
}

void main() {
  late String homeTopbar;
  late String desktopAiTopbar;
  late String aiScreen;

  setUpAll(() {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final waSource =
        File('lib/screens/ai/widgets/wa_header.dart').readAsStringSync();

    homeTopbar = classBlock(
      mainSource,
      'class _MobileAppBar extends StatelessWidget',
    );
    desktopAiTopbar = classBlock(
      waSource,
      'class WaHeader extends StatelessWidget',
    );
    aiScreen = File('lib/screens/ai_screen.dart').readAsStringSync();
  });

  group('MEDCASES WEB — Home / IA topbar parity V1-B-R1', () {
    test('WaHeader é o owner produtivo do desktop IA', () {
      expect(
        aiScreen,
        contains('// Desktop: sem shell AppBar → mostra WaHeader próprio.'),
      );
      expect(aiScreen, contains('final showWaHeader = bp.isDesktop;'));
    });

    test('R1 está dentro do owner produtivo', () {
      expect(
        desktopAiTopbar,
        contains('MEDCASES_WEB_HOME_AI_TOPBAR_PARITY_V1_B_R1'),
      );
    });

    test('desktop IA não possui affordance de voltar', () {
      expect(desktopAiTopbar, isNot(contains('Icons.arrow_back_ios_new')));
      expect(desktopAiTopbar, isNot(contains('Navigator.maybePop(context)')));
      expect(desktopAiTopbar, isNot(contains('BackButton(')));
    });

    test('Home e IA compartilham altura e padding canônicos', () {
      for (final source in [homeTopbar, desktopAiTopbar]) {
        expect(source, contains('height: 48'));
        expect(
          source,
          contains('EdgeInsets.symmetric(horizontal: 12)'),
        );
      }
    });

    test('Home e IA compartilham a mesma escala tipográfica', () {
      for (final source in [homeTopbar, desktopAiTopbar]) {
        expect(source, contains('fontSize: 16'));
        expect(source, contains('fontWeight: FontWeight.w900'));
        expect(source, contains('letterSpacing: 1.2'));
      }
    });

    test('título desktop IA permanece no centro geométrico', () {
      expect(
        desktopAiTopbar,
        contains('const Expanded(child: SizedBox.shrink())'),
      );
      expect(desktopAiTopbar, contains('textAlign: TextAlign.center'));
      expect(
        desktopAiTopbar,
        contains('mainAxisAlignment: MainAxisAlignment.end'),
      );
      expect(desktopAiTopbar, contains("text: 'MEDCASES '"));
      expect(desktopAiTopbar, contains("text: 'IA'"));
    });

    test('brand IA usa verde canônico #009C3B', () {
      expect(desktopAiTopbar, contains('Color(0xFF009C3B)'));
    });

    test('ações desktop continuam presentes', () {
      for (final token in [
        'onSettings',
        'onHistory',
        'onNewChat',
        'historyCount',
        'MplusPulse',
        'Icons.history_rounded',
        'Icons.add_rounded',
        'Icons.menu_rounded',
      ]) {
        expect(desktopAiTopbar, contains(token), reason: token);
      }
    });

    testWidgets('widget compila, mede 48px e não renderiza back arrow',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            endDrawer: const Drawer(child: SizedBox.shrink()),
            body: WaHeader(
              onSettings: () {},
              onHistory: () {},
              onNewChat: () {},
              historyCount: 0,
              isConnected: false,
            ),
          ),
        ),
      );

      expect(find.byType(WaHeader), findsOneWidget);
      expect(tester.getSize(find.byType(WaHeader)).height, 48);
      expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    });
  });
}

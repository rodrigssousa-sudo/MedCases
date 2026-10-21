import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(
  String source,
  String declaration,
) {
  final start = source.indexOf(declaration);

  expect(
    start,
    greaterThanOrEqualTo(0),
    reason: 'Classe ausente: $declaration',
  );

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
      if (character == '\n') {
        lineComment = false;
      }
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

      if (character == quote) {
        quote = null;
      }

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

      if (depth == 0) {
        return source.substring(
          start,
          index + 1,
        );
      }
    }
  }

  fail('Classe sem fechamento: $declaration');
}

void main() {
  late String mainSource;
  late String mobileSource;
  late String homeTopbar;
  late String aiTopbar;

  setUpAll(() {
    mainSource = File(
      'lib/main.dart',
    ).readAsStringSync();

    mobileSource = File(
      'lib/screens/ai/widgets/'
      'mobile_ai_action_bar.dart',
    ).readAsStringSync();

    homeTopbar = classBlock(
      mainSource,
      'class _MobileAppBar '
      'extends StatelessWidget',
    );

    aiTopbar = classBlock(
      mobileSource,
      'class MobileAiActionBar '
      'extends StatelessWidget',
    );
  });

  group(
    'AI-VIS-B.2.4-R2 — topbar IA igual à Home',
    () {
      test(
        'usa o mesmo vidro da Home',
        () {
          expect(homeTopbar, contains('MedcasesTopbarGlass('));
          expect(aiTopbar, contains('MedcasesTopbarGlass('));
          final glass =
              File('lib/widgets/medcases_topbar_glass.dart').readAsStringSync();
          for (final token in [
            'ImageFilter.blur(sigmaX: 16, sigmaY: 16)',
            'width: 0.7',
            'blurRadius: 14'
          ]) {
            expect(glass, contains(token));
          }
        },
      );

      test(
        'usa altura útil de 48 pixels',
        () {
          expect(
            aiTopbar,
            contains('height: topPad + 48'),
          );

          expect(
            aiTopbar,
            contains('height: 48'),
          );

          expect(
            homeTopbar,
            contains('height: 48'),
          );

          expect(
            aiTopbar,
            isNot(
              contains('height: topPad + 56'),
            ),
          );

          expect(
            aiTopbar,
            isNot(
              contains('height: 56'),
            ),
          );
        },
      );

      test(
        'remove superfície e sombra antigas',
        () {
          for (final forbidden in const [
            'Color(0xFF111622)',
            'Color(0xFF2D3340)',
            'width: 0.5',
            'boxShadow:',
            'blurRadius: 6',
            'Offset(0, 2)',
          ]) {
            expect(
              aiTopbar,
              isNot(contains(forbidden)),
              reason: forbidden,
            );
          }
        },
      );

      test(
        'preserva notch e SafeArea física',
        () {
          for (final token in const [
            'View.of(context).padding.top',
            'View.of(context).devicePixelRatio',
            'EdgeInsets.only(top: topPad)',
          ]) {
            expect(
              aiTopbar,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'título utiliza a tipografia da Home',
        () {
          for (final source in [
            homeTopbar,
            aiTopbar,
          ]) {
            for (final token in const [
              "text: 'MEDCASES '",
              'fontSize: 16',
              'fontWeight: FontWeight.w900',
              'letterSpacing: 1.2',
              'TextAlign.center',
            ]) {
              expect(
                source,
                contains(token),
                reason: token,
              );
            }
          }

          expect(
            aiTopbar,
            contains('color: titlePrimaryColor'),
          );

          expect(
            aiTopbar,
            contains("text: 'CLINICAL'"),
          );

          expect(
            aiTopbar,
            contains('const Color(0xFF009C3B)'),
          );
          expect(
            aiTopbar,
            contains('const Color(0xFF009C3B)'),
          );
        },
      );

      test(
        'M+ permanece proprietário e intocado',
        () {
          for (final token in const [
            'onTap: onSettings',
            'behavior: HitTestBehavior.opaque',
            'AiConnectionIdentity(',
            'MplusPulse(',
            'class MplusPulse '
                'extends StatefulWidget',
            'class MplusPulseState '
                'extends State<MplusPulse>',
            'AnimationController(',
            'duration: const Duration'
                '(milliseconds: 1900)',
          ]) {
            expect(
              mobileSource,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'preserva callbacks obrigatórios e opcionais',
        () {
          for (final token in const [
            'required this.onHistory',
            'required this.onClear',
            'required this.onSettings',
            'final VoidCallback? onNewChat;',
            'final VoidCallback? onAmbassador;',
            'this.onNewChat,',
            'this.onAmbassador,',
          ]) {
            expect(
              mobileSource,
              contains(token),
              reason: token,
            );
          }

          expect(
            mobileSource,
            isNot(
              contains('required this.onNewChat'),
            ),
          );
        },
      );

      test(
        'embaixador permanece funcional',
        () {
          for (final token in const [
            'if (isPartner && '
                'onAmbassador != null)',
            'onTap: onAmbassador',
            'partnerTitle.isNotEmpty',
            "'Embaixador'",
            "const Text('👑'",
          ]) {
            expect(
              aiTopbar,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'não cria estado ou shell paralelo',
        () {
          for (final forbidden in const [
            'Scaffold(',
            'Navigator.',
            'ChangeNotifier',
            'StreamController',
            'Provider<',
            'FirebaseFirestore',
            'SharedPreferences',
            'SpeechToText',
          ]) {
            expect(
              aiTopbar,
              isNot(contains(forbidden)),
              reason: forbidden,
            );
          }
        },
      );
    },
  );
}

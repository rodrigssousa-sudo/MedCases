import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AI Light white reading surface V1-B-R13', () {
    late String ai;

    setUpAll(() {
      ai = File('lib/screens/ai_screen.dart').readAsStringSync();
    });

    test('chatBg tem um único owner Light branco / Dark preservado', () {
      expect(ai, contains('R13_AI_LIGHT_WHITE_CHATBG'));
      expect(
        RegExp(
          r'final\s+chatBg\s*=\s*dark\s*\?\s*palette\.background\s*:\s*const\s+Color\(0xFFFFFFFF\)\s*;',
        ).allMatches(ai).length,
        1,
      );
    });

    test('os dois consumidores produtivos de chatBg permanecem', () {
      expect(
        RegExp(r'color\s*:\s*chatBg\s*,').allMatches(ai).length,
        2,
      );
    });

    test('Study e Plantão continuam em seus caminhos existentes', () {
      expect(ai, contains('study_user_hidden'));
      expect(ai, contains('visible: !_longResponse'));
      expect(ai, contains('GuardiaClinicalResponseView('));
    });
  });
}

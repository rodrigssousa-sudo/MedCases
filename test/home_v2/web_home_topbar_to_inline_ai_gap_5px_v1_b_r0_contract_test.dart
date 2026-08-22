import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String homeV2;

  setUpAll(() {
    homeV2 = File('lib/home_v2/home_screen_v2.dart').readAsStringSync();
  });

  test('web Home topbar to inline IA gap is exactly 5px', () {
    expect(homeV2, contains('kIsWeb ? 5.0 : systemTopInset + 54.0'));
    expect(
      homeV2,
      contains('MEDCASES_WEB_HOME_40_TOPBAR_TO_INLINE_AI_GAP_5PX_V1_B_R0'),
    );
  });

  test('native top inset contract remains byte-semantic equivalent', () {
    expect(homeV2, contains('systemTopInset + 54.0'));
    expect(homeV2, contains('final systemTopInset = mediaQuery.padding.top;'));
  });

  test(
    'scroll still owns topContentPadding and inline IA remains first module',
    () {
      expect(homeV2, contains('topContentPadding,'));
      expect(homeV2, contains('InlineChat('));

      final padding = homeV2.indexOf('topContentPadding,');
      final chat = homeV2.indexOf('InlineChat(');
      expect(padding, greaterThanOrEqualTo(0));
      expect(chat, greaterThan(padding));
    },
  );

  test('old unconditional web topbar compensation is removed', () {
    expect(
      RegExp(
        r'final\s+(?:double\s+)?topContentPadding\s*=\s*'
        r'systemTopInset\s*\+\s*54\.0\s*;',
      ).hasMatch(homeV2),
      isFalse,
    );
  });
}

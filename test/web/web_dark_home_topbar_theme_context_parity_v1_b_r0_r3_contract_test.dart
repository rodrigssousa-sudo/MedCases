import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final start = source.indexOf('class $className');
  if (start < 0) {
    throw StateError('class not found: $className');
  }

  final open = source.indexOf('{', start);
  if (open < 0) {
    throw StateError('class opening brace not found: $className');
  }

  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final c = source[i];
    if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(start, i + 1);
      }
    }
  }

  throw StateError('class not closed: $className');
}

void main() {
  final main = File('lib/main.dart').readAsStringSync();
  final wa = File('lib/screens/ai/widgets/wa_header.dart').readAsStringSync();
  final composer = File(
    'lib/screens/ai/widgets/prompt_composer.dart',
  ).readAsStringSync();
  final home = File('lib/home_v2/home_screen_v2.dart').readAsStringSync();

  test('Home 40 topbar resolves theme from its own BuildContext', () {
    final owner = classBlock(main, '_WebWorkspaceBrandBar');

    expect(
      owner,
      contains('MEDCASES_WEB_DARK_HOME_TOPBAR_THEME_CONTEXT_PARITY_V1_B_R0_R3'),
    );
    expect(owner, contains('Theme.of(context).brightness == Brightness.dark'));
    expect(owner, isNot(contains('final bool dark;')));
    expect(owner, isNot(contains('required this.dark')));

    expect(
      RegExp(
        r'if\s*\(\s*leftPaneIndex\s*==\s*0\s*\)\s*'
        r'(?:const\s+)?_WebWorkspaceBrandBar\(\)',
      ).hasMatch(main),
      isTrue,
    );
    expect(main, isNot(contains('_WebWorkspaceBrandBar(dark: dark)')));
  });

  test('Home and AI topbars share the same theme source', () {
    final owner = classBlock(main, '_WebWorkspaceBrandBar');

    expect(owner, contains('Theme.of(context).brightness == Brightness.dark'));
    expect(wa, contains('Theme.of(context).brightness == Brightness.dark'));
  });

  test('Light and Dark canonical topbar colors remain intact', () {
    final owner = classBlock(main, '_WebWorkspaceBrandBar');

    for (final token in <String>[
      'const Color(0xFFECF1F3)',
      'const Color(0xFF1A1D23)',
      'Colors.white.withOpacity(0.70)',
      'const Color(0xFF252930).withOpacity(0.70)',
      'const Color(0xFFE2E7EC)',
      'const Color(0xFF374151)',
      'ImageFilter.blur(sigmaX: 14, sigmaY: 14)',
      'height: 48',
    ]) {
      expect(owner, contains(token), reason: token);
    }
  });

  test('Light composer homologation remains intact', () {
    for (final token in <String>[
      'MEDCASES_WEB_LIGHT_MOBILE_PARITY_COMPOSER_V1_B_R0',
      'final composerSurface = palette.surfaceSoft;',
      'final composerText = palette.textPrimary;',
      'final composerSecondary = palette.textSecondary;',
    ]) {
      expect(composer, contains(token), reason: token);
    }
  });

  test('Home top gap remains exactly 5px on Web', () {
    expect(home, contains('kIsWeb ? 5.0 : systemTopInset + 54.0'));
  });

  test('R3 contract scopes legacy-dark checks to Home topbar owner only', () {
    final owner = classBlock(main, '_WebWorkspaceBrandBar');
    expect(owner, isNot(contains('final bool dark;')));
    expect(owner, isNot(contains('required this.dark')));

    // Other unrelated classes in main.dart may legitimately own a `dark`
    // field; they must not invalidate this topbar-specific contract.
    expect(main.length, greaterThan(owner.length));
  });
}

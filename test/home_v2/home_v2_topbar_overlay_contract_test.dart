import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String matchingBlock(
  String source,
  RegExp startPattern,
  String label,
) {
  final match = startPattern.firstMatch(source);

  expect(
    match,
    isNotNull,
    reason: 'Bloco ausente: $label',
  );

  final start = match!.start;
  final braceStart = source.indexOf('{', start);

  expect(
    braceStart,
    greaterThanOrEqualTo(0),
    reason: 'Abertura ausente: $label',
  );

  var depth = 0;

  for (var index = braceStart; index < source.length; index++) {
    final char = source[index];

    if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;

      if (depth == 0) {
        return source.substring(start, index + 1);
      }
    }
  }

  fail('Fechamento ausente: $label');
}

void main() {
  late String mobileShell;
  late String mobileAppBar;
  late String homeScreen;

  setUpAll(() {
    final mainSource = File(
      'lib/main.dart',
    ).readAsStringSync();

    final homeSource = File(
      'lib/home_v2/home_screen_v2.dart',
    ).readAsStringSync();

    mobileShell = matchingBlock(
      mainSource,
      RegExp(
        r'Widget\s+_buildMobileShell\s*\([^{]*\)\s*\{',
      ),
      '_buildMobileShell',
    );

    mobileAppBar = matchingBlock(
      mainSource,
      RegExp(
        r'class\s+_MobileAppBar\b[^{]*\{',
      ),
      '_MobileAppBar',
    );

    homeScreen = matchingBlock(
      homeSource,
      RegExp(
        r'class\s+HomeScreenV2\b[^{]*\{',
      ),
      'HomeScreenV2',
    );
  });

  group('Home V2 — sobreposição real da topbar', () {
    test('body se estende atrás da appBar somente na Home', () {
      expect(
        mobileShell,
        contains('extendBodyBehindAppBar: isHome'),
      );

      expect(
        mobileShell,
        contains('appBar: isHome'),
      );

      expect(
        mobileShell,
        isNot(
          contains('extendBodyBehindAppBar: true'),
        ),
      );
    });

    test('padding superior é preservado apenas para a Home', () {
      expect(
        mobileShell,
        contains('removeTop: !isHome'),
      );

      expect(
        mobileShell,
        isNot(contains('removeTop: false')),
      );
    });

    test('topbar não possui escudo opaco externo', () {
      expect(
        mobileAppBar,
        isNot(contains('return ColoredBox(')),
      );

      expect(
        mobileAppBar,
        isNot(contains('color: baseColor')),
      );

      expect(
        mobileAppBar,
        isNot(contains('final baseColor')),
      );

      expect(
        mobileAppBar,
        contains('return ClipRect('),
      );

      expect(
        mobileAppBar,
        contains('BackdropFilter('),
      );
    });

    test('vidro e altura permanecem intactos', () {
      expect(
        mobileAppBar,
        contains(
          'const Color(0xFF252930).withOpacity(0.70)',
        ),
      );

      expect(
        mobileAppBar,
        contains(
          'Colors.white.withOpacity(0.70)',
        ),
      );

      expect(
        mobileAppBar,
        contains(
          'ImageFilter.blur(sigmaX: 14, sigmaY: 14)',
        ),
      );

      expect(
        mobileAppBar,
        contains('height: 48'),
      );

      expect(
        mobileAppBar,
        contains('SafeArea('),
      );
    });

    test('Home compensa sistema, topbar e respiro no scroll', () {
      expect(
        homeScreen,
        contains(
          'final systemTopInset = mediaQuery.padding.top;',
        ),
      );

      expect(
        homeScreen,
        contains(
          'final topContentPadding = systemTopInset + 54.0;',
        ),
      );

      expect(
        homeScreen,
        contains(
          'horizontalPadding,\n'
          '                topContentPadding,\n'
          '                horizontalPadding,',
        ),
      );
    });

    test('Home mantém um único scroll vertical', () {
      expect(
        RegExp(
          r'SingleChildScrollView\s*\(',
        ).allMatches(homeScreen).length,
        1,
      );

      expect(
        homeScreen,
        isNot(contains('CustomScrollView(')),
      );

      expect(
        homeScreen,
        isNot(contains('ListView(')),
      );
    });

    test('padding inferior permanece preservado', () {
      expect(
        homeScreen,
        contains('systemBottomInset + 152.0'),
      );

      expect(
        homeScreen,
        contains('bottomContentPadding'),
      );
    });
  });
}

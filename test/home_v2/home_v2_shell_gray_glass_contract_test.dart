import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final match = RegExp(
    'class\\s+$className\\b[^\\{]*\\{',
  ).firstMatch(source);

  expect(
    match,
    isNotNull,
    reason: 'Classe ausente: $className',
  );

  final start = match!.start;
  final braceStart = source.indexOf('{', start);

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

  fail('Fechamento ausente: $className');
}

void main() {
  late String mobileAppBar;
  late String legalGlassShelf;
  late String legalBar;

  setUpAll(() {
    final source = File(
      'lib/main.dart',
    ).readAsStringSync();

    mobileAppBar = classBlock(
      source,
      '_MobileAppBar',
    );

    legalGlassShelf = classBlock(
      source,
      '_LegalGlassShelf',
    );

    legalBar = classBlock(
      source,
      '_LegalBar',
    );
  });

  group('MainShell — topbar cinza esmerilada', () {
    test('usa vidro cinza de alta opacidade no dark', () {
      expect(
        mobileAppBar,
        contains(
          'const Color(0xFF252930).withOpacity(0.70)',
        ),
      );

      expect(
        mobileAppBar,
        contains('const Color(0xFF374151)'),
      );
    });

    test('permanece branca no modo light', () {
      expect(
        mobileAppBar,
        contains(
          'Colors.white.withOpacity(0.70)',
        ),
      );

      expect(
        mobileAppBar,
        contains('const Color(0xFFE2E7EC)'),
      );
    });

    test('mantém blur 14 e borda de 0.7 px', () {
      expect(
        mobileAppBar,
        contains(
          'ImageFilter.blur(sigmaX: 14, sigmaY: 14)',
        ),
      );

      expect(
        mobileAppBar,
        contains(
          'BorderSide(color: borderColor, width: 0.7)',
        ),
      );
    });

    test('não possui fundo opaco antes do BackdropFilter', () {
      expect(
        mobileAppBar,
        isNot(contains('final baseColor')),
      );

      expect(
        mobileAppBar,
        isNot(contains('color: baseColor')),
      );

      expect(
        mobileAppBar,
        isNot(contains('return ColoredBox(')),
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

    test('remove sombra e tons azuis antigos', () {
      expect(
        mobileAppBar,
        isNot(contains('boxShadow:')),
      );

      const forbidden = <String>[
        '0xFF070D16',
        '0xFF101C2C',
        '0xFF263A55',
        'withOpacity(0.62)',
        'withOpacity(0.66)',
      ];

      for (final token in forbidden) {
        expect(
          mobileAppBar,
          isNot(contains(token)),
          reason: 'Token antigo na topbar: $token',
        );
      }
    });
  });

  group('MainShell — faixa legal cinza esmerilada', () {
    test('compartilha o vidro cinza da topbar', () {
      expect(
        legalGlassShelf,
        contains(
          'const Color(0xFF252930).withOpacity(0.70)',
        ),
      );

      expect(
        legalGlassShelf,
        contains(
          'Colors.white.withOpacity(0.70)',
        ),
      );

      expect(
        legalGlassShelf,
        contains('const Color(0xFF374151)'),
      );
    });

    test('usa blur 14 e borda superior de 0.7 px', () {
      expect(
        legalGlassShelf,
        contains(
          'ImageFilter.blur(sigmaX: 14, sigmaY: 14)',
        ),
      );

      expect(
        legalGlassShelf,
        contains('width: 0.7'),
      );
    });

    test('não conserva o perfil anterior', () {
      const forbidden = <String>[
        '0xFF0F1722',
        '0xFF263A55',
        'withOpacity(0.82)',
        'sigmaX: 12',
        'sigmaY: 12',
      ];

      for (final token in forbidden) {
        expect(
          legalGlassShelf,
          isNot(contains(token)),
          reason: 'Token antigo na faixa legal: $token',
        );
      }
    });

    test('fallback dark usa cinza e light permanece igual', () {
      expect(
        legalBar,
        contains('const Color(0xFF1A1D23)'),
      );

      expect(
        legalBar,
        contains('const Color(0xFFF0F2F4)'),
      );

      expect(
        legalBar,
        contains('const Color(0xFF374151)'),
      );

      expect(
        legalBar,
        contains('const Color(0xFFDDE1E6)'),
      );
    });

    test('preserva conteúdo legal e proteção inferior', () {
      expect(
        legalBar,
        contains(
          'Ferramenta educacional de apoio clínico.',
        ),
      );

      expect(
        legalBar,
        contains(
          'Herramienta educativa de apoyo clínico.',
        ),
      );

      expect(
        legalBar,
        contains('SafeArea('),
      );

      expect(
        legalGlassShelf,
        contains(
          'padding: EdgeInsets.only(bottom: safeBottom)',
        ),
      );
    });
  });
}

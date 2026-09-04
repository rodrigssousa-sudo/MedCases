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
    final character = source[index];

    if (character == '{') {
      depth++;
    } else if (character == '}') {
      depth--;

      if (depth == 0) {
        return source.substring(start, index + 1);
      }
    }
  }

  fail('Fechamento ausente: $className');
}

bool matches(String source, String pattern) {
  return RegExp(
    pattern,
    multiLine: true,
  ).hasMatch(source);
}

void main() {
  late String footer;
  late String navItem;

  setUpAll(() {
    final source = File(
      'lib/main.dart',
    ).readAsStringSync();

    footer = classBlock(
      source,
      '_FloatingFooterState',
    );

    navItem = classBlock(
      source,
      '_NavItem',
    );
  });

  group('MainShell — barra inferior adaptativa', () {
    test('itens comuns usam branco no dark e verde ativo', () {
      expect(
        matches(
          navItem,
          r'final activeColor\s*=\s*dark\s*\?'
          r'\s*const Color\(0xFF00C781\)\s*:'
          r'\s*const Color\(0xFF008F66\)\s*;',
        ),
        isTrue,
      );

      expect(
        matches(
          navItem,
          r'final inactiveColor\s*=\s*dark\s*\?'
          r'\s*Colors\.white\s*:'
          r'\s*const Color\(0xFF4B5563\)\s*;',
        ),
        isTrue,
      );

      expect(
        navItem,
        contains(
          'final color = isActive ? activeColor : inactiveColor;',
        ),
      );

      expect(
        navItem,
        contains(
          'child: Icon(resolvedIcon, size: 22, color: color)',
        ),
      );
    });

    test('Início e Biblioteca preservam _NavItem e destinos', () {
      expect(
        footer,
        contains('icon: Icons.home_outlined'),
      );

      expect(
        footer,
        contains('iconActive: Icons.home_rounded'),
      );

      expect(
        footer,
        contains('icon: Icons.menu_book_outlined'),
      );

      expect(
        footer,
        contains('iconActive: Icons.menu_book_rounded'),
      );

      expect(
        footer,
        contains('widget.onTabChange(0)'),
      );

      expect(
        footer,
        contains('widget.onTabChange(5)'),
      );
    });

    test('IA usa branco inativo e verde ativo', () {
      expect(
        matches(
          footer,
          r'Icons\.psychology_rounded\s*,'
          r'[\s\S]*?color\s*:\s*widget\.isAiActive\s*\?'
          r'\s*\(widget\.dark\s*\?'
          r'\s*_medcasesGreen\s*:'
          r'\s*_menuLightGreen\s*\)'
          r'\s*:\s*Colors\.white\s*,',
        ),
        isTrue,
      );

      expect(
        matches(
          footer,
          r"child\s*:\s*Text\('IA'"
          r'[\s\S]*?color\s*:\s*widget\.isAiActive\s*\?'
          r'\s*\(widget\.dark\s*\?'
          r'\s*_medcasesGreen\s*:'
          r'\s*_menuLightGreen\s*\)'
          r'\s*:\s*\(widget\.dark\s*\?'
          r'\s*Colors\.white\s*:'
          r'\s*const Color\(0xFF4B5563\)\s*\)',
        ),
        isTrue,
      );
    });

    test('M+ usa branco e responde em verde ao toque', () {
      expect(
        footer,
        contains('bool _menuPressed = false;'),
      );

      expect(
        matches(
          footer,
          r'final menuColor\s*=\s*_menuPressed\s*\?'
          r'\s*\(widget\.dark\s*\?'
          r'\s*_medcasesGreen\s*:'
          r'\s*_menuLightGreen\s*\)'
          r'\s*:\s*\(widget\.dark\s*\?'
          r'\s*Colors\.white\s*:'
          r'\s*const Color\(0xFF4B5563\)\s*\)\s*;',
        ),
        isTrue,
      );

      expect(
        footer,
        contains('onTapDown: (_)'),
      );

      expect(
        footer,
        contains('onTapUp: (_)'),
      );

      expect(
        footer,
        contains('onTapCancel: ()'),
      );

      expect(
        footer,
        contains('onTap: widget.onMenuTap'),
      );

      expect(
        footer,
        isNot(contains('0xFFD4AF37')),
      );

      expect(
        footer,
        isNot(contains('color: _avatarGold')),
      );
    });

    test('preserva vidro, alturas e recolhimento', () {
      expect(
        footer,
        contains(
          'const Color(0xFF0F1116).withOpacity(0.68)',
        ),
      );

      expect(
        footer,
        contains(
          'Colors.white.withOpacity(0.65)',
        ),
      );

      expect(
        footer,
        contains(
          'static const _barHeightFull = 50.0',
        ),
      );

      expect(
        footer,
        contains(
          'static const _barHeightShrunk = 38.0',
        ),
      );

      expect(
        footer,
        contains('MainShell.navScrollingDown'),
      );
    });

    test('preserva os callbacks oficiais', () {
      expect(
        footer,
        contains('widget.onFabTap'),
      );

      expect(
        footer,
        contains('widget.onFabDoubleTap'),
      );

      expect(
        footer,
        contains('widget.onMenuTap'),
      );

      expect(
        footer,
        contains('Widget _buildAiRow()'),
      );
    });
  });
}

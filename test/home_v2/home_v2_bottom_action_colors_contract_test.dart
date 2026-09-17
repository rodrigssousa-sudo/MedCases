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
    test('itens comuns usam branco no dark e verde oficial ativo', () {
      // O R21 utiliza verde #009C3B nos dois temas. A cor inativa
      // permanece branca no dark e cinza #4B5563 no light.
      expect(
        matches(navItem,
          r'final activeColor\s*=\s*dark\s*\?'
          r'\s*const Color\(0xFF009C3B\)\s*:'
          r'\s*const Color\(0xFF009C3B\)\s*;'),
        isTrue,
      );
      expect(
        matches(navItem,
          r'final inactiveColor\s*=\s*dark\s*\?'
          r'\s*Colors\.white\s*:'
          r'\s*const Color\(0xFF4B5563\)\s*;'),
        isTrue,
      );
      expect(navItem, contains('final color = isActive ? activeColor : inactiveColor;'));
      expect(navItem, contains('child: Icon(resolvedIcon, size: 22, color: color)'));
    });
    test('Início e navegação IA contextual preservam os destinos', () {
      // Biblioteca foi retirada do dock. O destino Home continua index 0;
      // IA muda o conteúdo do dock para Histórico / Novo Chat / Menu.
      expect(footer, contains('Widget _buildNavRow()'));
      expect(footer, contains('Widget _buildAiRow()'));
      expect(footer, contains('icon: Icons.home_outlined'));
      expect(footer, contains('iconActive: Icons.home_rounded'));
      expect(footer, contains('widget.onTabChange(0)'));
      expect(footer, contains('AiScreen.openHistoryCallback'));
      expect(footer, contains('widget.onFabDoubleTap'));
      expect(footer, isNot(contains('icon: Icons.menu_book_outlined')));
    });
    test('IA utiliza SVG oficial, ação de abertura e rótulo adaptativo', () {
      expect(footer, contains("'assets/icons/home_v2/ic_ia.svg'"));
      expect(footer, contains('onTap: widget.onFabTap'));
      expect(footer, contains('onDoubleTap: widget.onFabDoubleTap'));
      expect(footer, contains("child: Text('IA',"));
      expect(footer, contains('color: widget.isAiActive'));
      expect(footer, contains('_medcasesGreen'));
      expect(footer, contains('Colors.white'));
      expect(footer, contains('const Color(0xFF4B5563)'));
    });
    test('M+ mantém retorno tátil verde e contraste por tema', () {
      expect(footer, contains('bool _menuPressed = false;'));
      expect(footer, contains('final menuColor = _menuPressed'));
      expect(footer, contains('const Color(0xFF009C3B)'));
      expect(footer, contains('widget.dark ? Colors.white : const Color(0xFF4B5563)'));
      for (final callback in const [
        'onTapDown: (_)', 'onTapUp: (_)', 'onTapCancel: ()',
        'onTap: widget.onMenuTap',
      ]) {
        expect(footer, contains(callback), reason: callback);
      }
      expect(footer, isNot(contains('0xFFD4AF37')));
      expect(footer, isNot(contains('color: _avatarGold')));
    });
    test('preserva liquid glass, alturas, safe area e recolhimento', () {
      for (final token in const [
        'const Color(0xFF161B22).withValues(alpha: 0.58)',
        'Colors.white.withValues(alpha: 0.56)',
        'ImageFilter.blur(sigmaX: 16, sigmaY: 16)',
        'liquidBorder',
        'liquidSpecular',
        'static const _barHeightFull = 50.0',
        'static const _barHeightShrunk = 38.0',
        'MainShell.navScrollingDown',
        'final safeBottom = bottomInset > 0 ? bottomInset : 16.0',
      ]) {
        expect(footer, contains(token), reason: token);
      }
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

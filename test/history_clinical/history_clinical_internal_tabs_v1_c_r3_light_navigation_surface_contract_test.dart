import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

String classSlice(String text, String name) {
  final match =
      RegExp(r'class\s+' + RegExp.escape(name) + r'\b').firstMatch(text);
  expect(match, isNotNull, reason: 'Classe ausente: $name');
  final opening = text.indexOf('{', match!.start);
  var depth = 0;
  String? quote;
  var escaped = false;
  var lineComment = false;
  var blockComment = false;
  for (var i = opening; i < text.length; i++) {
    final c = text[i];
    final n = i + 1 < text.length ? text[i + 1] : '';
    if (lineComment) {
      if (c == '\n') lineComment = false;
      continue;
    }
    if (blockComment) {
      if (c == '*' && n == '/') {
        blockComment = false;
        i++;
      }
      continue;
    }
    if (quote != null) {
      if (escaped) {
        escaped = false;
      } else if (c == r'\') {
        escaped = true;
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    if (c == '/' && n == '/') {
      lineComment = true;
      i++;
      continue;
    }
    if (c == '/' && n == '*') {
      blockComment = true;
      i++;
      continue;
    }
    if (c == "'" || c == '"') {
      quote = c;
      continue;
    }
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth == 0) return text.substring(match.start, i + 1);
    }
  }
  fail('Classe sem fechamento: $name');
}

void main() {
  late String history;
  late String mainSource;
  late String inlineChat;
  setUpAll(() {
    history = source('lib/screens/history_screen.dart');
    mainSource = source('lib/main.dart');
    inlineChat = source('lib/home_v2/components/chat/inline_chat_view.dart');
  });

  test('rota produtiva e footer global permanecem preservados', () {
    expect(RegExp(r'\bHistoryScreen\s*\(').allMatches(mainSource).length, 1);
    expect(
        mainSource, contains('class _FloatingFooter extends StatefulWidget'));
    expect(history, isNot(contains('_FloatingFooter(')));
    expect(history, isNot(contains('bottomNavigationBar:')));
  });

  test('fundação light usa canvas, divisor e texto clínicos oficiais', () {
    final row = classSlice(history, '_HcTabRow');
    final flat = classSlice(history, '_HcFlatTabState');
    final screen = classSlice(history, '_HistoryScreenState');
    final card = classSlice(history, '_HistoryCard');
    expect(
        row, contains('HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R3_TABROW_LIGHT'));
    expect(
        flat, contains('HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R3_FLATTAB_LIGHT'));
    expect(screen,
        contains('HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R3_SCREEN_CANVAS_LIGHT'));
    expect(card,
        contains('HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R3_HISTORY_CARD_LIGHT'));
    expect('$row$screen', contains('Color(0xFFECF1F3)'));
    expect('$row$card', contains('Color(0xFFD8E0E7)'));
    expect('$flat$card', contains('Color(0xFF05070A)'));
    expect(card, contains('Colors.transparent'));
  });

  test('expressões dark e ações internas continuam presentes', () {
    for (final token in <String>[
      'Color(0xFF1A1D23)',
      'Color(0xFF252930)',
      'Color(0xFF374151)',
      'saveHistory(',
      'deleteHistory(',
      '_openOcrPicker',
      'Printing.',
      'RepaintBoundary',
    ]) {
      expect(history, contains(token), reason: 'Contrato ausente: $token');
    }
  });

  test('owners funcionais protegidos continuam existentes', () {
    for (final owner in <String>[
      '_HistoryPreviewSheet',
      '_HistoryEditorState',
      '_HistoryDetailState'
    ]) {
      expect(history, contains('class $owner'));
    }
    expect(inlineChat, contains('class'));
  });
}

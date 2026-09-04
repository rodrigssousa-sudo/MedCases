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

  test('R3 permanece e somente o light branch explícito do editor muda', () {
    for (final marker in <String>[
      'HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R3_TABROW_LIGHT',
      'HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R3_FLATTAB_LIGHT',
      'HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R3_SCREEN_CANVAS_LIGHT',
      'HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R3_HISTORY_CARD_LIGHT',
    ]) {
      expect(history, contains(marker), reason: 'Baseline R3 ausente: $marker');
    }

    final preview = classSlice(history, '_HistoryPreviewSheet');
    final editor = classSlice(history, '_HistoryEditorState');
    final detail = classSlice(history, '_HistoryDetailState');

    expect(
      editor,
      contains(
          'HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R6_HISTORYEDITORSTATE_LIGHT'),
      reason: 'Editor sem marcador da correção explícita',
    );
    expect(
      preview,
      isNot(contains('HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R6_')),
      reason: 'Preview dark não poderia receber mutação R6',
    );
    expect(
      detail,
      isNot(contains('HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R6_')),
      reason: 'Detalhe/exportação dark não poderia receber mutação R6',
    );
    expect(
      editor,
      contains('Color(0xFFECF1F3)'),
      reason: 'Canvas light clínico não encontrado no editor',
    );

    final unsafePureWhiteLightBranch = RegExp(
      r'\?\s*(?:const\s+)?Color\(0xFF(?:1A1D23|252930|2D3340)\)\s*:\s*(?:Colors\.white\b|const Color\(0xFFFFFFFF\))',
      multiLine: true,
    );
    expect(
      unsafePureWhiteLightBranch.hasMatch(editor),
      isFalse,
      reason:
          'Ainda existe canvas branco puro em light branch explicitamente temático',
    );

    // 0xFF0F1116 pode permanecer legitimamente como foreground sobre ação verde.
    expect(preview, contains('Color(0xFF1A1D23)'));
    expect(detail, contains('Color(0xFF1A1D23)'));
  });

  test('dark, persistência, áudio, IA e exportação continuam presentes', () {
    for (final token in <String>[
      'Color(0xFF1A1D23)',
      'Color(0xFF252930)',
      'Color(0xFF374151)',
      'saveHistory(',
      'deleteHistory(',
      '_openOcrPicker',
      'Printing.',
      'RepaintBoundary',
      'TextEditingController',
      'FocusNode',
      'dispose(',
      'initState(',
    ]) {
      expect(history, contains(token), reason: 'Contrato ausente: $token');
    }
  });

  test('nenhuma rota, footer ou chat congelado foi duplicado', () {
    expect(RegExp(r'class\s+HistoryScreen\b').allMatches(history).length, 1);
    expect(inlineChat, contains('class'));
  });
}
